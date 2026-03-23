import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../providers/reservation_provider.dart';
import '../widgets/time_slot_picker.dart';

class ReservationScreen extends ConsumerStatefulWidget {
  final String stationId;
  final String stationName;
  final String connectorId;
  final String connectorType;
  final double pricePerKwh;

  const ReservationScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.connectorId,
    required this.connectorType,
    required this.pricePerKwh,
  });

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  TimeOfDay? _selectedTime;
  int _selectedDuration = 30;
  final double _reservationFee = 10.0; // Fixed reservation fee for now

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  Future<void> _handleBooking() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start time'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final start = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (start.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot book in the past'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final end = start.add(Duration(minutes: _selectedDuration));

    final notifier = ref.read(reservationActionProvider.notifier);
    final result = await notifier.createReservation(
      stationId: widget.stationId,
      connectorId: widget.connectorId,
      start: start,
      end: end,
      fee: _reservationFee,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _showSuccessDialog(result['reservation_id']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Booking failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog(String reservationId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text('Reserved!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your connector has been reserved.'),
            const SizedBox(height: 16),
            Text('ID: $reservationId', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('A ₹10.00 fee was deducted from your wallet.', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.pop(); // Go back to station details
            },
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(reservationActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reserve Connector'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station Info Card
            GlassCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.electrical_services_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stationName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${widget.connectorType} • ₹${widget.pricePerKwh}/kWh',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Calendar
            const Text(
              'Select Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 7)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: const CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: AppColors.primary)),
                  ),
                  defaultTextStyle: TextStyle(color: AppColors.textPrimary),
                  weekendTextStyle: TextStyle(color: AppColors.textSecondary),
                ),
                headerStyle: const HeaderStyle(
                  titleTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textPrimary),
                  rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time & Duration
            TimeSlotPicker(
              selectedDate: _selectedDay,
              selectedTime: _selectedTime,
              selectedDuration: _selectedDuration,
              onTimeSelected: (time) => setState(() => _selectedTime = time),
              onDurationSelected: (dur) => setState(() => _selectedDuration = dur),
            ),
            const SizedBox(height: 40),

            // Bottom Summary & Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reservation Fee', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text('₹${_reservationFee.toStringAsFixed(2)}', 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: NeonButton(
                      label: 'Book Now',
                      isLoading: actionState.isLoading,
                      onPressed: _handleBooking,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
