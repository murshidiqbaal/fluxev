class UserEntity {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isGuest => role == 'guest';
}
