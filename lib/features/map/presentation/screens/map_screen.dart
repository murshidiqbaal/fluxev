import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../stations/data/models/station_model.dart';
import '../../../stations/data/repositories/station_repository.dart';
import '../../../stations/domain/entities/station_entity.dart';

// Distance utility - calculates distance between two coordinates using Haversine formula
class DistanceHelper {
  static const double _earthRadiusKm = 6371;

  static double calculateDistance(LatLng from, LatLng to) {
    final dLat = _toRadian(to.latitude - from.latitude);
    final dLng = _toRadian(to.longitude - from.longitude);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadian(from.latitude)) *
            math.cos(_toRadian(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _toRadian(double degree) {
    return degree * math.pi / 180;
  }
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  LatLng? _userLocation;
  List<Marker> _stationMarkers = [];
  StationEntity? _selectedStation;
  bool _loading = true;
  bool _locationLoading = false;
  String? _locationError;
  List<StationEntity> _allStations = [];
  static const _defaultCenter = LatLng(8.5241, 76.9366);
  static const double _nearbyRadiusKm = 5.0; // Filter stations within 5km

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getUserLocation();
    await _fetchAndBuildMarkers();
  }

  Future<void> _fetchAndBuildMarkers() async {
    try {
      final stations = await _fetchStations();
      setState(() {
        _allStations = stations;
        _stationMarkers = stations.map((s) => _buildMarker(s)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching stations: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<List<StationEntity>> _fetchStations() async {
    final client = Supabase.instance.client;
    final data = await client.from('stations').select('''
      *,
      connectors(id, status, connector_type, max_power_kw)
    ''');
    return (data as List).map((j) => StationModel.fromJson(j)).toList();
  }

  /// Get nearby stations within [_nearbyRadiusKm] of user location
  List<StationEntity> _getNearbyStations() {
    if (_userLocation == null) return [];

    return _allStations.where((station) {
      final distance =
          DistanceHelper.calculateDistance(_userLocation!, station.latLng);
      return distance <= _nearbyRadiusKm;
    }).toList()
      ..sort((a, b) =>
          DistanceHelper.calculateDistance(_userLocation!, a.latLng).compareTo(
              DistanceHelper.calculateDistance(_userLocation!, b.latLng)));
  }

  Marker _buildMarker(StationEntity station) {
    return Marker(
      width: 50,
      height: 50,
      point: station.latLng,
      child: GestureDetector(
        onTap: () => setState(() => _selectedStation = station),
        child: Container(
          decoration: BoxDecoration(
            color: _markerColor(station),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _markerColor(station).withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    try {
      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _locationLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permission permanently denied. Enable in settings.';
          _locationLoading = false;
        });
        // Optionally open app settings
        await Geolocator.openLocationSettings();
        return;
      }

      // Get current position
      final pos = await Geolocator.getCurrentPosition(
        // timeoutDuration: const Duration(seconds: 10),
        forceAndroidLocationManager: true,
      );

      final newLocation = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _userLocation = newLocation;
        _locationLoading = false;
      });

      // Move map to user location with animation
      _mapController.move(newLocation, 14);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Location updated'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Error: ${e.toString()}';
          _locationLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    }
  }

  Color _markerColor(StationEntity station) {
    if (!station.isActive) return AppColors.markerOffline;
    if (station.hasAvailableConnectors) return AppColors.markerAvailable;
    return AppColors.markerBusy;
  }

  void _showNearbyStationsSheet() {
    final nearbyStations = _getNearbyStations();

    if (nearbyStations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stations found nearby')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => _NearbyStationsSheet(
        stations: nearbyStations,
        userLocation: _userLocation!,
        onStationSelected: (station) {
          Navigator.pop(context);
          setState(() => _selectedStation = station);
          _mapController.move(station.latLng, 16);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(allStationsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Map
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? _defaultCenter,
                    initialZoom: 12,
                    onTap: (_, __) => setState(() => _selectedStation = null),
                  ),
                  children: [
                    // OSM tile layer
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fluxev.flux_ev',
                    ),
                    // Marker layers
                    MarkerLayer(
                      markers: [
                        // User location marker
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withOpacity(0.5),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Station markers from state
                        ..._stationMarkers,
                      ],
                    ),
                  ],
                ),

          // Top header bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            const Text('FLUXEV',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3)),
                            const Spacer(),
                            stationsAsync
                                    .whenData(
                                      (s) => Text(
                                        '${s.where((x) => x.hasAvailableConnectors).length} Available',
                                        style: const TextStyle(
                                            color: AppColors.markerAvailable,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    )
                                    .valueOrNull ??
                                const SizedBox.shrink(),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => ref
                                  .read(authNotifierProvider.notifier)
                                  .signOut(),
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Logout',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().slideY(begin: -1, duration: 500.ms),
          ),

          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ActionButton(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan QR',
                      onTap: () => context.push(AppRoutes.qrScanner),
                    ),
                    _ActionButton(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Wallet',
                      onTap: () {
                        // Navigate to wallet screen
                        context.push(AppRoutes.wallet);
                      },
                    ),
                    _ActionButton(
                      icon: Icons.my_location_rounded,
                      label: 'My Location',
                      onTap: _locationLoading ? null : _getUserLocation,
                      isLoading: _locationLoading,
                    ),
                    _ActionButton(
                      icon: Icons.location_searching,
                      label: 'Nearby',
                      onTap: _userLocation == null
                          ? null
                          : _showNearbyStationsSheet,
                    ),
                  ],
                ),
              ),
            ).animate().slideY(begin: 1, duration: 500.ms),
          ),

          // Selected Station Card
          if (_selectedStation != null)
            Positioned(
              bottom: 110,
              left: 16,
              right: 16,
              child: GlassCard(
                borderColor: _markerColor(_selectedStation!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _markerColor(_selectedStation!),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedStation!.isActive
                              ? _selectedStation!.hasAvailableConnectors
                                  ? 'Available'
                                  : 'All Busy'
                              : 'Offline',
                          style: TextStyle(
                            color: _markerColor(_selectedStation!),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_userLocation != null)
                          Text(
                            '${DistanceHelper.calculateDistance(_userLocation!, _selectedStation!.latLng).toStringAsFixed(2)} km away',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              setState(() => _selectedStation = null),
                          icon: const Icon(Icons.close, size: 18),
                          color: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedStation!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedStation!.address,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _InfoChip(
                          label:
                              '${_selectedStation!.availableConnectors}/${_selectedStation!.totalConnectors} ports',
                          icon: Icons.power_outlined,
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          label:
                              '₹${_selectedStation!.pricePerKwh.toStringAsFixed(2)}/kWh',
                          icon: Icons.bolt_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.push('/station/${_selectedStation!.id}'),
                        child: const Text('View Station Details'),
                      ),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 0.3, duration: 300.ms),
            ),
        ],
      ),
    );
  }
}

// Enhanced Action Button with loading state
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(isDisabled ? 0.5 : 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDisabled
                ? AppColors.cardBorder.withOpacity(0.5)
                : AppColors.cardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(isDisabled ? 0.05 : 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              )
            else
              Icon(
                icon,
                color: isDisabled ? AppColors.textSecondary : AppColors.primary,
                size: 24,
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDisabled
                    ? AppColors.textSecondary.withOpacity(0.6)
                    : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Nearby Stations Bottom Sheet
class _NearbyStationsSheet extends StatelessWidget {
  final List<StationEntity> stations;
  final LatLng userLocation;
  final Function(StationEntity) onStationSelected;

  const _NearbyStationsSheet({
    required this.stations,
    required this.userLocation,
    required this.onStationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Nearby Stations (${stations.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stations list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: stations.length,
              itemBuilder: (context, index) {
                final station = stations[index];
                final distance = DistanceHelper.calculateDistance(
                    userLocation, station.latLng);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => onStationSelected(station),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.cardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: station.isActive
                                      ? AppColors.markerAvailable
                                      : AppColors.markerOffline,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  station.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${distance.toStringAsFixed(2)} km',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            station.address,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _InfoChip(
                                  label:
                                      '${station.availableConnectors}/${station.totalConnectors}',
                                  icon: Icons.power_outlined,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _InfoChip(
                                  label:
                                      '₹${station.pricePerKwh.toStringAsFixed(2)}',
                                  icon: Icons.bolt_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
