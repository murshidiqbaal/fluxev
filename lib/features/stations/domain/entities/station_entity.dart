import 'package:latlong2/latlong.dart';

class StationEntity {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double pricePerKwh;
  final String status; // active, inactive
  final int availableConnectors;
  final int totalConnectors;
  final double? avgRating;

  const StationEntity({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.pricePerKwh,
    required this.status,
    required this.availableConnectors,
    required this.totalConnectors,
    this.avgRating,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  bool get isActive => status == 'active';
  bool get hasAvailableConnectors => availableConnectors > 0;
}
