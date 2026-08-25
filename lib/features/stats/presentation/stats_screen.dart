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
  
  Map<String, dynamic> _delays = {};
  Map<String, dynamic> _oddEvenRatio = {};
  Map<String, dynamic> _frequentDecades = {};
  Map<String, dynamic> _frequentPairs = {};
  Map<String, dynamic> _frequentTriplets = {};
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
          .select('hot_numbers, cold_numbers, target_date, delays, odd_even_ratio, frequent_decades, frequent_pairs, frequent_triplets')
          .order('target_date', ascending: false)
          .limit(1)
          .single();

      setState(() {
        _hotNumbers = List<int>.from(response['hot_numbers'] ?? []);
        _coldNumbers = List<int>.from(response['cold_numbers'] ?? []);
        _targetDate = response['target_date'] ?? '';
        
        _delays = response['delays'] ?? {};
        _oddEvenRatio = response['odd_even_ratio'] ?? {};
        _frequentDecades = response['frequent_decades'] ?? {};
        _frequentPairs = response['frequent_pairs'] ?? {};
        _frequentTriplets = response['frequent_triplets'] ?? {};
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberGrid(List<int> numbers, Color color) {
    if (numbers.isEmpty) return const Text('Nessun dato', style: TextStyle(color: Colors.white54));
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: numbers.map((n) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
            )
          ]
        ),
        child: Center(
          child: Text(
            n.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildKeyValueCard(String title, Map<String, dynamic> data, String valueSuffix, {Color? valueColor}) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...data.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  Text('${e.value}$valueSuffix', style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildOddEvenBar() {
    double pari = (_oddEvenRatio['pari'] as num?)?.toDouble() ?? 50.0;
    double dispari = (_oddEvenRatio['dispari'] as num?)?.toDouble() ?? 50.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pari: ${pari}%', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            Text('Dispari: ${dispari}%', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Expanded(
                flex: pari.round(),
                child: Container(height: 12, color: Colors.blueAccent),
              ),
              Expanded(
                flex: dispari.round(),
                child: Container(height: 12, color: Colors.pinkAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Text('Errore: $_errorMessage\n(Hai eseguito l\'aggiornamento SQL del database?)', 
            textAlign: TextAlign.center, 
            style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Statistiche Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1E2C), Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Dati calcolati su tutto l\'archivio storico. Ultimo aggiornamento: $_targetDate',
                          style: const TextStyle(color: Colors.amber, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('I 10 Più Ritardatari', Icons.hourglass_bottom),
                _buildKeyValueCard('Ritardo in Estrazioni', _delays, ' turni', valueColor: Colors.redAccent),
                
                const SizedBox(height: 24),
                _buildSectionTitle('I Numeri più "Caldi" dell\'IA', Icons.local_fire_department),
                _buildNumberGrid(_hotNumbers, Colors.orangeAccent),
                
                const SizedBox(height: 32),
                _buildSectionTitle('Ambi e Terni più Frequenti', Icons.link),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildKeyValueCard('Ambi d\'Oro', _frequentPairs, ' volte')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildKeyValueCard('Terni Storici', _frequentTriplets, ' volte')),
                  ],
                ),
                
                const SizedBox(height: 32),
                _buildSectionTitle('Analisi Pari vs Dispari', Icons.balance),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: _buildOddEvenBar(),
                ),
                
                const SizedBox(height: 32),
                _buildSectionTitle('Frequenza Decine', Icons.bar_chart),
                _buildKeyValueCard('Uscite per Decina (Storico)', _frequentDecades, ' presenze', valueColor: Colors.cyanAccent),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
