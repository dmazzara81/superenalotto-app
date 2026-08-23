import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:superenalotto/features/premium_analytics/presentation/analytics_dashboard.dart';
import 'package:superenalotto/features/auth/presentation/login_screen.dart';
import 'package:superenalotto/features/home/presentation/home_screen.dart';
import 'package:superenalotto/features/stats/presentation/stats_screen.dart';
import 'package:superenalotto/features/systems/presentation/systems_hub_screen.dart';

// Placeholder screen per le funzionalità non ancora implementate
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Schermata $title in costruzione...')),
    );
  }
}

// =====================================================================
// PROFILO TEMPORANEO (Mostra lo stato di login)
// =====================================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: Center(
        child: user == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Non sei autenticato.', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: const Text('VAI AL LOGIN', style: TextStyle(color: Colors.black)),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Accesso effettuato come:\n${user.email}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) context.go('/');
                    },
                    child: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
});

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        onNavigate: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const StatsScreen(),
      const AnalyticsDashboardScreen(), // Ora usa la schermata reale
      const SystemsHubScreen(),
      const ProfileScreen(), // Usa il profilo dinamico Supabase
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            activeIcon: Icon(Icons.psychology),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hub_outlined),
            activeIcon: Icon(Icons.hub),
            label: 'Sistemi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
