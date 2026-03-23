import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/reservation_repository.dart';
import '../../domain/reservation.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepository(Supabase.instance.client);
});

final myReservationsStreamProvider = StreamProvider<List<Reservation>>((ref) {
  return ref.watch(reservationRepositoryProvider).watchMyReservations();
});

final myReservationsProvider = FutureProvider<List<Reservation>>((ref) {
  return ref.watch(reservationRepositoryProvider).getMyReservations();
});

class ReservationNotifier extends StateNotifier<AsyncValue<void>> {
  final ReservationRepository _repository;

  ReservationNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>> createReservation({
    required String stationId,
    required String connectorId,
    required DateTime start,
    required DateTime end,
    required double fee,
  }) async {
    state = const AsyncValue.loading();
    final result = await _repository.createReservation(
      stationId: stationId,
      connectorId: connectorId,
      start: start,
      end: end,
      fee: fee,
    );
    
    if (result['success'] == true) {
      state = const AsyncValue.data(null);
    } else {
      state = AsyncValue.error(result['message'] ?? 'Unknown error', StackTrace.current);
    }
    
    return result;
  }

  Future<void> cancelReservation(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.cancelReservation(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final reservationActionProvider = StateNotifierProvider<ReservationNotifier, AsyncValue<void>>((ref) {
  return ReservationNotifier(ref.watch(reservationRepositoryProvider));
});
