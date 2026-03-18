import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) return Left(AuthFailure('Login failed'));

      final userEntity = await _getOrCreateProfile(user);
      return Right(userEntity);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      final user = response.user;
      if (user == null) return Left(AuthFailure('Sign up failed'));

      // Wait briefly for DB trigger, then ensure profile exists
      await Future.delayed(const Duration(milliseconds: 800));
      final userEntity = await _getOrCreateProfile(user);
      return Right(userEntity);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return Left(AuthFailure('Not authenticated'));

      final userEntity = await _getOrCreateProfile(user);
      return Right(userEntity);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;
      try {
        return await _getOrCreateProfile(user);
      } catch (_) {
        return null;
      }
    });
  }

  /// Helper to ensure a profile exists in the 'users' table
  Future<UserEntity> _getOrCreateProfile(User user) async {
    final profile =
        await _client.from('users').select().eq('id', user.id).maybeSingle();

    if (profile != null) {
      return UserModel.fromJson(profile);
    }

    // Fallback: Create profile if missing (e.g. trigger delay or failure)
    final newProfile = {
      'id': user.id,
      'email': user.email ?? '',
      'full_name': user.userMetadata?['full_name'] ?? '',
      'role': 'user',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _client.from('users').upsert(newProfile);
    } catch (_) {
      // Ignore upsert errors if it already exists by now
    }

    return UserModel.fromJson(newProfile);
  }
}
