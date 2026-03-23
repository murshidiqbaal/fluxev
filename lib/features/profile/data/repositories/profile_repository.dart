import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<ProfileModel?> getProfile(String id) async {
    final response = await _client
        .from('user_profiles')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }

  Future<void> createProfile(ProfileModel profile) async {
    await _client.from('user_profiles').insert(profile.toJson());
  }

  Future<void> updateProfile(ProfileModel profile) async {
    await _client
        .from('user_profiles')
        .update(profile.toJson())
        .eq('id', profile.id);
  }

  Future<String> uploadAvatar(File imageFile, String userId) async {
    final fileExt = imageFile.path.split('.').last;
    final fileName = '$userId.$fileExt';
    final filePath = 'avatars/$fileName';

    await _client.storage.from('avatars').upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return _client.storage.from('avatars').getPublicUrl(filePath);
  }
}
