import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../../../stations/data/repositories/station_repository.dart';

class StationDetailScreen extends ConsumerWidget {
  final String stationId;

  const StationDetailScreen({super.key, required this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationAsync = ref.watch(singleStationProvider(stationId));

    return Scaffold(
      body: stationAsync.when(
        data: (station) {
          if (station == null) {
            return const Center(child: Text('Station not found'));
          }
          return CustomScrollView(
            slivers: [
              // App bar with gradient
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceVariant,
                          AppColors.background,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryDark.withOpacity(0.15),
                              border: Border.all(
                                  color: AppColors.primary, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.ev_station_rounded,
                                color: AppColors.primary, size: 44),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            station.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => context.pop(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Status pill
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: station.hasAvailableConnectors
                                ? AppColors.markerAvailable.withOpacity(0.15)
                                : AppColors.markerBusy.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: station.hasAvailableConnectors
                                  ? AppColors.markerAvailable
                                  : AppColors.markerBusy,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: station.hasAvailableConnectors
                                      ? AppColors.markerAvailable
                                      : AppColors.markerBusy,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                station.hasAvailableConnectors
                                    ? 'Available Now'
                                    : 'All Busy',
                                style: TextStyle(
                                  color: station.hasAvailableConnectors
                                      ? AppColors.markerAvailable
                                      : AppColors.markerBusy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 16),
                    // Stats grid
                    GlassCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: 'Price',
                                  value:
                                      '₹${station.pricePerKwh.toStringAsFixed(2)}',
                                  unit: '/ kWh',
                                  icon: Icons.bolt_rounded,
                                ),
                              ),
                              Container(width: 1, height: 60, color: AppColors.divider),
                              Expanded(
                                child: _StatTile(
                                  label: 'Connectors',
                                  value:
                                      '${station.availableConnectors}/${station.totalConnectors}',
                                  unit: 'free',
                                  icon: Icons.power_outlined,
                                ),
                              ),
                              Container(width: 1, height: 60, color: AppColors.divider),
                              Expanded(
                                child: _StatTile(
                                  label: 'Rating',
                                  value: station.avgRating != null
                                      ? station.avgRating!.toStringAsFixed(1)
                                      : 'N/A',
                                  unit: '/ 5.0',
                                  icon: Icons.star_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate(delay: 400.ms).fadeIn().slide(begin: const Offset(0, 0.2)),
                    const SizedBox(height: 12),
                    // Address
                    GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: AppColors.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              station.address,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 500.ms).fadeIn(),
                    const SizedBox(height: 24),
                    // Scan to charge
                    NeonButton(
                      label: 'Scan QR to Start Charging',
                      icon: Icons.qr_code_scanner_rounded,
                      onPressed: () => context.push(AppRoutes.qrScanner),
                    ).animate(delay: 600.ms).fadeIn(),
                    const SizedBox(height: 12),
                    // Navigate
                    NeonButton(
                      label: 'Navigate',
                      isOutlined: true,
                      icon: Icons.navigation_outlined,
                      onPressed: () async {
                        final url = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${station.latitude},${station.longitude}',
                        );
                        if (await canLaunchUrl(url)) launchUrl(url);
                      },
                    ).animate(delay: 700.ms).fadeIn(),
                    const SizedBox(height: 12),
                    NeonButton(
                      label: 'View Reviews',
                      isOutlined: true,
                      icon: Icons.rate_review_outlined,
                      onPressed: () =>
                          context.push('/station/${station.id}/reviews'),
                    ).animate(delay: 800.ms).fadeIn(),
                    const SizedBox(height: 32),

                    // Connectors Section
                    Text(
                      'Connectors',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate(delay: 900.ms).fadeIn(),
                    const SizedBox(height: 12),
                    ...station.connectors.map((connector) {
                      final status = connector['status'] as String;
                      final type = connector['connector_type'] as String;
                      final power = (connector['max_power_kw'] as num).toDouble();
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.power_input_rounded, color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${power.toStringAsFixed(0)} kW • $status',
                                      style: TextStyle(
                                        color: status == 'available' 
                                          ? AppColors.markerAvailable 
                                          : AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (status == 'available')
                                TextButton(
                                  onPressed: () => context.push(
                                    AppRoutes.reserve,
                                    extra: {
                                      'stationId': station.id,
                                      'stationName': station.name,
                                      'connectorId': connector['id'],
                                      'connectorType': type,
                                      'pricePerKwh': station.pricePerKwh,
                                    },
                                  ),
                                  child: const Text('Reserve'),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) =>
            Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(unit,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
