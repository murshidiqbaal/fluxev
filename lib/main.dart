import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/deep_link_utils.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('❌ Supabase initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: FluxEvApp(),
    ),
  );
}

class FluxEvApp extends ConsumerWidget {
  const FluxEvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    // Simple deep link handling logic
    Future<void> handleDeepLink(String link) async {
      final connectorId = DeepLinkUtils.extractConnectorId(link);

      if (connectorId == null) {
        debugPrint('❌ Invalid or missing connector ID in deep link: $link');
        return;
      }

      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;

        if (userId == null) {
          debugPrint('⚠️ User not logged in, cannot start session from deep link');
          return;
        }

        await client.from('charging_sessions').insert({
          'user_id': userId,
          'connector_id': connectorId,
          'status': 'active',
        });
        debugPrint('✅ Charging session created from deep link for connector: $connectorId');
      } catch (e) {
        debugPrint('❌ Failed to create session from deep link: $e');
      }
    }

    return MaterialApp.router(
      title: 'FluxEV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
