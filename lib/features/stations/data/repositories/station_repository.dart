import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/station_entity.dart';
import '../models/station_model.dart';

final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return StationRepository(Supabase.instance.client);
});

class StationRepository {
  final SupabaseClient _client;

  StationRepository(this._client);

  Future<List<StationEntity>> getAllStations() async {
    final data = await _client.from('stations').select('''
      *,
      connectors(id, status, connector_type, max_power_kw)
    ''').eq('status', 'active');
    return (data as List).map((j) => StationModel.fromJson(j)).toList();
  }

  Future<StationEntity?> getStation(String id) async {
    final data = await _client.from('stations').select('''
      *,
      connectors(id, status, connector_type, max_power_kw)
    ''').eq('id', id).maybeSingle();
    return StationModel.fromJson(data!);
  }

  Stream<List<Map<String, dynamic>>> watchConnectorStatus() {
    return _client.from('connectors').stream(
        primaryKey: ['id']).map((list) => list.cast<Map<String, dynamic>>());
  }

  Future<void> addStation(Map<String, dynamic> data) async {
    await _client.from('stations').insert(data);
  }

  Future<void> updateStation(String id, Map<String, dynamic> data) async {
    await _client.from('stations').update(data).eq('id', id);
  }
}

// Providers
final allStationsProvider = FutureProvider<List<StationEntity>>((ref) async {
  final repo = ref.watch(stationRepositoryProvider);
  return repo.getAllStations();
});

final singleStationProvider =
    FutureProvider.family<StationEntity?, String>((ref, id) async {
  final repo = ref.watch(stationRepositoryProvider);
  return repo.getStation(id);
});
