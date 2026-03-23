import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TimeSlotPicker extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay? selectedTime;
  final int selectedDuration; // in minutes
  final Function(TimeOfDay) onTimeSelected;
  final Function(int) onDurationSelected;

  const TimeSlotPicker({
    super.key,
    required this.selectedDate,
    this.selectedTime,
    required this.selectedDuration,
    required this.onTimeSelected,
    required this.onDurationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Start Time',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: Colors.black,
                      surface: AppColors.surface,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (time != null) {
              onTimeSelected(time);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedTime?.format(context) ?? 'Pick a time',
                  style: TextStyle(
                    color: selectedTime != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const Icon(Icons.access_time_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Duration',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [30, 45, 60].map((duration) {
            final isSelected = selectedDuration == duration;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: duration == 60 ? 0 : 8),
                child: InkWell(
                  onTap: () => onDurationSelected(duration),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.cardBorder,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$duration min',
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
