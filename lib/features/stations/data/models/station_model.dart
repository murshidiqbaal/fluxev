import '../../domain/entities/station_entity.dart';

class StationModel extends StationEntity {
  const StationModel({
    required super.id,
    required super.name,
    required super.address,
    required super.latitude,
    required super.longitude,
    required super.pricePerKwh,
    required super.status,
    required super.availableConnectors,
    required super.totalConnectors,
    super.avgRating,
    required super.connectors,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) {
    final connectors = (json['connectors'] as List?) ?? [];
    final total = connectors.length;
    final available =
        connectors.where((c) => c['status'] == 'available').length;

    return StationModel(
      id: (json['station_id'] ?? json['id']) as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      pricePerKwh: (json['price_per_kwh'] as num).toDouble(),
      status: json['status'] as String? ?? 'active',
      totalConnectors: total,
      availableConnectors: available,
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      connectors: (json['connectors'] as List?)?.map((c) {
            final map = Map<String, dynamic>.from(c);
            if (map.containsKey('connector_id')) {
              map['id'] = map['connector_id'];
            }
            return map;
          }).toList() ??
          [],
    );
  }
}
