import 'package:equatable/equatable.dart';

class ProfileModel extends Equatable {
  final String id;
  final String fullName;
  final String phone;
  final String vehicleType;
  final String vehicleModel;
  final String? licensePlate;
  final String? avatarUrl;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    required this.vehicleModel,
    this.licensePlate,
    this.avatarUrl,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? '',
      vehicleModel: json['vehicle_model'] as String? ?? '',
      licensePlate: json['license_plate'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'vehicle_type': vehicleType,
      'vehicle_model': vehicleModel,
      'license_plate': licensePlate,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? fullName,
    String? phone,
    String? vehicleType,
    String? vehicleModel,
    String? licensePlate,
    String? avatarUrl,
  }) {
    return ProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      licensePlate: licensePlate ?? this.licensePlate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        phone,
        vehicleType,
        vehicleModel,
        licensePlate,
        avatarUrl,
        createdAt,
      ];
}
