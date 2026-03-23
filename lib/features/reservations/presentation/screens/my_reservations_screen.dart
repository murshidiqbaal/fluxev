import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/reservation.dart';
import '../providers/reservation_provider.dart';

class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(myReservationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reservations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy_rounded,
                      color: AppColors.textSecondary, size: 64),
                  const SizedBox(height: 16),
                  const Text('No reservations found',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(200, 50),
                    ),
                    child: const Text('Go back to Map'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reservations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = reservations[i];
              final isActive = r.status == ReservationStatus.active;

              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(status: r.status),
                        const Spacer(),
                        Text(
                          AppFormatters.formatCurrency(r.reservationFee),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r.stationName ?? 'Station #${r.stationId.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.power_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Connector ID: ${r.connectorId.substring(0, 8)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TimeColumn(label: 'START', time: r.reservedStart),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.divider),
                        _TimeColumn(label: 'END', time: r.reservedEnd, crossAxisAlignment: CrossAxisAlignment.end),
                      ],
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _confirmCancel(context, ref, r.id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error, width: 1.5),
                            minimumSize: const Size(double.infinity, 45),
                          ),
                          child: const Text('Cancel Reservation'),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate(delay: (i * 50).ms).fadeIn().slideY(begin: 0.1, duration: 300.ms);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Reservation?'),
        content: const Text('Are you sure you want to cancel this reservation? The fee will be refunded to your wallet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(reservationActionProvider.notifier).cancelReservation(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation cancelled')),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final ReservationStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ReservationStatus.active:
        color = AppColors.primary;
        break;
      case ReservationStatus.completed:
        color = AppColors.success;
        break;
      case ReservationStatus.cancelled:
        color = AppColors.error;
        break;
      case ReservationStatus.expired:
        color = AppColors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  final String label;
  final DateTime time;
  final CrossAxisAlignment crossAxisAlignment;

  const _TimeColumn({
    required this.label,
    required this.time,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppFormatters.formatDate(time),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
