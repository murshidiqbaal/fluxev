import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shake/shake.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/glass_card.dart';
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
  late ShakeDetector _shakeDetector;
  final _searchController = TextEditingController();
  List<StationEntity> _filteredStations = [];
  bool _isSearching = false;
  static const _defaultCenter = LatLng(8.5241, 76.9366);
  static const double _nearbyRadiusKm = 5.0; // Filter stations within 5km

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (event) {
        if (mounted) {
          context.push(AppRoutes.profile);
        }
      },
      shakeThresholdGravity: 2.7,
    );
  }

  @override
  void dispose() {
    _shakeDetector.stopListening();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
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
      connectors(connector_id, status, connector_type, max_power_kw)
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
    final isSelected = _selectedStation?.id == station.id;
    final color = _markerColor(station);

    return Marker(
      width: 60,
      height: 60,
      point: station.latLng,
      child: GestureDetector(
        onTap: () => setState(() => _selectedStation = station),
        child: AnimatedContainer(
          duration: 300.ms,
          curve: Curves.easeOutBack,
          transform: Matrix4.identity()..scale(isSelected ? 1.2 : 1.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: isSelected ? 20 : 12,
                      spreadRadius: isSelected ? 4 : 2,
                    ),
                  ],
                ),
              ),
              // Marker body
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _markerIcon(station),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _markerIcon(StationEntity station) {
    if (!station.isActive) return Icons.power_off_rounded;
    if (station.hasAvailableConnectors) return Icons.bolt_rounded;
    return Icons.timer_rounded;
  }

  Future<void> _openMapsNavigation(double lat, double lng) async {
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final appleMapsUrl = 'http://maps.apple.com/?daddr=$lat,$lng';

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl),
            mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch maps application')),
        );
      }
    }
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

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredStations = [];
      });
      return;
    }

    final filtered = _allStations.where((s) {
      final nameMatches = s.name.toLowerCase().contains(query.toLowerCase());
      final addressMatches =
          s.address.toLowerCase().contains(query.toLowerCase());
      return nameMatches || addressMatches;
    }).toList();

    setState(() {
      _isSearching = true;
      _filteredStations = filtered;
    });
  }

  void _selectStation(StationEntity station) {
    setState(() {
      _selectedStation = station;
      _isSearching = false;
      _searchController.text = station.name;
    });
    _mapController.move(station.latLng, 16);
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
                      tileBuilder: (context, tileWidget, tile) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            -1, 0, 0, 0, 255, // Red
                            0, -1, 0, 0, 255, // Green
                            0, 0, -1, 0, 255, // Blue
                            0, 0, 0, 1, 0, // Alpha
                          ]),
                          child: Opacity(
                            opacity: 0.85,
                            child: tileWidget,
                          ),
                        );
                      },
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

          // Top Search Bar & Results
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Hero(
                      tag: 'search_bar',
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        borderRadius: 30,
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded,
                                color: AppColors.primary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15),
                                decoration: const InputDecoration(
                                  hintText: 'Search stations, location...',
                                  hintStyle: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: _onSearchChanged,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white70, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                            const SizedBox(width: 8),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.tune_rounded,
                                  color: AppColors.primary, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Search Results
                  if (_isSearching && _filteredStations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 20,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _filteredStations.length,
                            itemBuilder: (context, index) {
                              final station = _filteredStations[index];
                              return ListTile(
                                leading: Icon(
                                  Icons.ev_station_rounded,
                                  color: _markerColor(station),
                                ),
                                title: Text(
                                  station.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  station.address,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: _userLocation != null
                                    ? Text(
                                        '${DistanceHelper.calculateDistance(_userLocation!, station.latLng).toStringAsFixed(1)} km',
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11),
                                      )
                                    : null,
                                onTap: () {
                                  _selectStation(station);
                                  FocusScope.of(context).unfocus();
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ).animate().fadeIn().slideY(begin: -0.1),
                ],
              ),
            ).animate().slideY(
                begin: -1, duration: 600.ms, curve: Curves.easeOutCubic),
          ),

          // Right Floating Floating Controls
          Positioned(
            right: 16,
            bottom: _selectedStation != null ? 320 : 100,
            child: Column(
              children: [
                _CircularGlassButton(
                  icon: Icons.refresh_rounded,
                  onTap: _fetchAndBuildMarkers,
                ),
                const SizedBox(height: 12),
                _CircularGlassButton(
                  icon: Icons.filter_list_rounded,
                  onTap: _showNearbyStationsSheet,
                ),
                const SizedBox(height: 12),
                _CircularGlassButton(
                  icon: Icons.my_location_rounded,
                  onTap: _getUserLocation,
                  isLoading: _locationLoading,
                ),
              ],
            )
                .animate(target: _selectedStation != null ? 1 : 0)
                .moveY(end: -220, duration: 300.ms),
          ),

          // Bottom Bar (Horizontal glass)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: SafeArea(
              child: GlassCard(
                borderRadius: 25,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CompactActionButton(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan QR',
                      onTap: () => context.push(AppRoutes.qrScanner),
                    ),
                    _CompactActionButton(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Wallet',
                      onTap: () => context.push(AppRoutes.wallet),
                    ),
                    _CompactActionButton(
                      icon: Icons.event_note_rounded,
                      label: 'Bookings',
                      onTap: () => context.push(AppRoutes.myReservations),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .slideY(begin: 1, duration: 600.ms, curve: Curves.easeOutCubic),
          ),

          // Selected Station Card (Sliding panel)
          if (_selectedStation != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: GlassCard(
                borderRadius: 24,
                borderColor: _markerColor(_selectedStation!).withOpacity(0.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _markerColor(_selectedStation!)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _markerColor(_selectedStation!),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedStation!.isActive
                                    ? _selectedStation!.hasAvailableConnectors
                                        ? 'Available'
                                        : 'Busy'
                                    : 'Offline',
                                style: TextStyle(
                                  color: _markerColor(_selectedStation!),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_userLocation != null)
                          Text(
                            '${DistanceHelper.calculateDistance(_userLocation!, _selectedStation!.latLng).toStringAsFixed(1)} km',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _selectedStation = null),
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: Colors.white70),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedStation!.name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedStation!.address,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _DetailChip(
                          icon: Icons.power_rounded,
                          label:
                              '${_selectedStation!.availableConnectors}/${_selectedStation!.totalConnectors} Available',
                        ),
                        const SizedBox(width: 8),
                        _DetailChip(
                          icon: Icons.bolt_rounded,
                          label: '₹${_selectedStation!.pricePerKwh}/kWh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context
                                .push('/station/${_selectedStation!.id}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('RESERVE NOW'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: IconButton(
                            onPressed: () => _openMapsNavigation(
                              _selectedStation!.latLng.latitude,
                              _selectedStation!.latLng.longitude,
                            ),
                            icon: const Icon(Icons.directions_rounded,
                                color: AppColors.primary),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
                  .animate()
                  .slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
            ),
        ],
      ),
    );
  }
}

class _CircularGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _CircularGlassButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 25,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
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
