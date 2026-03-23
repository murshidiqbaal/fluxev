import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

final profileProvider = FutureProvider<ProfileModel?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  
  return ref.watch(profileRepositoryProvider).getProfile(user.id);
});

class ProfileActionNotifier extends StateNotifier<AsyncValue<void>> {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileActionNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> setupProfile({
    required String fullName,
    required String phone,
    required String vehicleType,
    required String vehicleModel,
    String? licensePlate,
    File? avatarFile,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _repository.uploadAvatar(avatarFile, user.id);
      }

      final profile = ProfileModel(
        id: user.id,
        fullName: fullName,
        phone: phone,
        vehicleType: vehicleType,
        vehicleModel: vehicleModel,
        licensePlate: licensePlate,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now(),
      );

      await _repository.createProfile(profile);
      _ref.invalidate(profileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile({
    required ProfileModel profile,
    File? avatarFile,
  }) async {
    state = const AsyncValue.loading();
    try {
      String? avatarUrl = profile.avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _repository.uploadAvatar(avatarFile, profile.id);
      }

      final updatedProfile = profile.copyWith(
        avatarUrl: avatarUrl,
      );

      await _repository.updateProfile(updatedProfile);
      _ref.invalidate(profileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final profileActionProvider = StateNotifierProvider<ProfileActionNotifier, AsyncValue<void>>((ref) {
  return ProfileActionNotifier(ref.watch(profileRepositoryProvider), ref);
});
