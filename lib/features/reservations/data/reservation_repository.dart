import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reservation.dart';

class ReservationRepository {
  final SupabaseClient _client;

  ReservationRepository(this._client);

  Future<List<Reservation>> getMyReservations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client.from('reservations').select('''
  reservation_id,
  user_id,
  station_id,
  connector_id,
  reserved_start,
  reserved_end,
  reservation_fee,
  status,
  created_at,
  stations:station_id (
    station_id:id,
    name,
    address,
    latitude,
    longitude
  ),
  connectors:connector_id (
    connector_id:id,
    connector_type,
    max_power_kw,
    status
  )
''').eq('user_id', userId).order('reserved_start', ascending: false);

    return (response as List)
        .map((json) => Reservation.fromJson(json))
        .toList();
  }

  Future<Map<String, dynamic>> createReservation({
    required String stationId,
    required String connectorId,
    required DateTime start,
    required DateTime end,
    required double fee,
  }) async {
    try {
      final response = await _client.rpc(
        'create_reservation_with_payment',
        params: {
          'p_connector_id': connectorId,
          'p_station_id': stationId,
          'p_start': start.toIso8601String(),
          'p_end': end.toIso8601String(),
          'p_fee': fee,
        },
      );

      return response as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: Create Reservation Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Stream<List<Reservation>> watchMyReservations() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _client
        .from('reservations')
        .stream(primaryKey: ['reservation_id'])
        .eq('user_id', userId)
        .map((data) => data.map((json) => Reservation.fromJson(json)).toList());
  }

  Future<void> cancelReservation(String id) async {
    await _client
        .from('reservations')
        .update({'status': 'cancelled'}).eq('reservation_id', id);
  }
}
