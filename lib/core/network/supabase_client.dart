// import 'package:flux_ev/core/network/supabase_client.dart' as supabase;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase
    show SupabaseClient;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClient {
  static SupabaseClient? _instance;
  final supabase = Supabase.instance.client;

  SupabaseClient._internal();

  static SupabaseClient get instance {
    _instance ??= SupabaseClient._internal();
    return _instance!;
  }
}

// Convenience getter
supabase.SupabaseClient get supabaseClient => Supabase.instance.client;
