import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<int> _hotNumbers = [];
  List<int> _coldNumbers = [];
  List<int> _ssHotNumbers = [];
  List<int> _ssColdNumbers = [];
  String _targetDate = '';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await Supabase.instance.client
          .from('number_probabilities')
          .select('hot_numbers, cold_numbers, superstar_hot, superstar_cold, target_date')
          .order('target_date', ascending: false)
          .limit(1)
          .single();

      setState(() {
        _hotNumbers = List<int>.from(response['hot_numbers'] ?? []);
        _coldNumbers = List<int>.from(response['cold_numbers'] ?? []);
        _ssHotNumbers = List<int>.from(response['superstar_hot'] ?? []);
        _ssColdNumbers = List<int>.from(response['superstar_cold'] ?? []);
        _targetDate = response['target_date'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Errore nel caricamento delle statistiche: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistiche Base', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'SESTINA BASE'),
              Tab(text: 'SUPERSTAR'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      // TAB 1: SESTINA BASE
                      _buildStatsTab(
                        title: 'Trend Sestina',
                        hotNumbers: _hotNumbers,
                        coldNumbers: _coldNumbers,
                      ),
                      // TAB 2: SUPERSTAR
                      _buildStatsTab(
                        title: 'Trend SuperStar',
                        hotNumbers: _ssHotNumbers.isNotEmpty ? _ssHotNumbers : _hotNumbers, // Fallback
                        coldNumbers: _ssColdNumbers.isNotEmpty ? _ssColdNumbers : _coldNumbers, // Fallback
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatsTab({required String title, required List<int> hotNumbers, required List<int> coldNumbers}) {
    return RefreshIndicator(
      onRefresh: _fetchStats,
      color: Colors.amber,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aggiornati al $_targetDate',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 32),

            // INFO BOX
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blueAccent),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Queste classifiche mostrano la pura frequenza storica passata.\nNon sono previsioni per il futuro. Usa l\'IA Ensemble per calcolare la probabilità della prossima estrazione.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            // HOT NUMBERS
            _buildNumberSection(
              title: 'I 10 Numeri più Caldi 🔥',
              description: 'I numeri che sono stati estratti con maggiore frequenza storicamente.',
              numbers: hotNumbers,
              gradientColors: [Colors.orange.shade800, Colors.red.shade900],
              shadowColor: Colors.red.withOpacity(0.5),
            ),

            const SizedBox(height: 32),

            // COLD NUMBERS
            _buildNumberSection(
              title: 'I 10 Numeri più Freddi 🧊',
              description: 'I numeri che sono usciti meno frequentemente nello storico.',
              numbers: coldNumbers,
              gradientColors: [Colors.blue.shade800, Colors.cyan.shade900],
              shadowColor: Colors.cyan.withOpacity(0.5),
            ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.amber),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Sblocca il Generatore PRO per combinare i pesi e creare la combinazione perfetta.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberSection({
    required String title,
    required String description,
    required List<int> numbers,
    required List<Color> gradientColors,
    required Color shadowColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 15,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: numbers.map((num) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.last.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    num.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
