import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

// Supabase client provider
final supabaseClientProvider = Provider<sb.SupabaseClient>(
  (ref) => sb.Supabase.instance.client,
);

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepositoryImpl(client);
});

// Auth state stream provider (watches Supabase session changes)
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

// Current user provider
final currentUserProvider = FutureProvider<UserEntity?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final result = await repo.getCurrentUser();
  return result.fold((_) => null, (user) => user);
});

// Auth actions notifier
class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _repo.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
    });
  }

  Future<String?> login(String email, String password) async {
    state = const AsyncValue.loading();
    final result = await _repo.login(email: email, password: password);
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (user) {
        state = AsyncValue.data(user);
        return null;
      },
    );
  }

  Future<String?> signUp(String fullName, String email, String password) async {
    state = const AsyncValue.loading();
    final result = await _repo.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (user) {
        state = AsyncValue.data(user);
        return null;
      },
    );
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
