import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:superenalotto/core/routing/app_router.dart';
import 'package:superenalotto/core/theme/app_theme.dart';
import 'package:superenalotto/core/services/revenuecat_service.dart';

// Inserite le vere chiavi del progetto Supabase
const String supabaseUrl = 'https://fcokqyuccicfxqxughih.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjb2txeXVjY2ljZnhxeHVnaGloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNTM5MTQsImV4cCI6MjEwMjcyOTkxNH0.oy14vfptubBuS4LzUbhgKI9luuFGNUhG0dQvzdwIpg0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializzazione SDK Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  // Inizializzazione RevenueCat
  await RevenueCatService().init();

  runApp(
    const ProviderScope(
      child: SuperEnalottoApp(),
    ),
  );
}

class SuperEnalottoApp extends ConsumerWidget {
  const SuperEnalottoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SuperEnalotto Analytics',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
