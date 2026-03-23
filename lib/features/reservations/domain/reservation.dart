enum ReservationStatus {
  active,
  cancelled,
  expired,
  completed;

  static ReservationStatus fromString(String status) {
    return ReservationStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => ReservationStatus.active,
    );
  }
}

class Reservation {
  final String id;
  final String userId;
  final String stationId;
  final String connectorId;
  final DateTime reservedStart;
  final DateTime reservedEnd;
  final double reservationFee;
  final ReservationStatus status;
  final DateTime createdAt;

  // Joined data (optional)
  final String? stationName;
  final String? connectorType;

  Reservation({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.connectorId,
    required this.reservedStart,
    required this.reservedEnd,
    required this.reservationFee,
    required this.status,
    required this.createdAt,
    this.stationName,
    this.connectorType,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['reservation_id'] as String,
      userId: json['user_id'] as String,
      stationId: json['station_id'] as String,
      connectorId: json['connector_id'] as String,
      reservedStart: DateTime.parse(json['reserved_start']),
      reservedEnd: DateTime.parse(json['reserved_end']),
      reservationFee: (json['reservation_fee'] ?? 0).toDouble(),
      status: ReservationStatus.fromString(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      stationName: json['stations']?['name'],
      connectorType: json['connectors']?['connector_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reservation_id': id,
      'user_id': userId,
      'station_id': stationId,
      'connector_id': connectorId,
      'reserved_start': reservedStart.toIso8601String(),
      'reserved_end': reservedEnd.toIso8601String(),
      'reservation_fee': reservationFee,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
