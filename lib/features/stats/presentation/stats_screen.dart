import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

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
  final Map<int, double> _probabilities = {};

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await Supabase.instance.client
          .from('number_probabilities')
          .select('hot_numbers, cold_numbers, superstar_hot, superstar_cold, probabilities, target_date')
          .order('target_date', ascending: false)
          .limit(1)
          .single();

      setState(() {
        _hotNumbers = List<int>.from(response['hot_numbers'] ?? []);
        _coldNumbers = List<int>.from(response['cold_numbers'] ?? []);
        _ssHotNumbers = List<int>.from(response['superstar_hot'] ?? []);
        _ssColdNumbers = List<int>.from(response['superstar_cold'] ?? []);
        _targetDate = response['target_date'] ?? '';
        
        final Map<String, dynamic>? rawProbs = response['probabilities'];
        if (rawProbs != null) {
          rawProbs.forEach((key, value) {
            _probabilities[int.parse(key)] = (value as num).toDouble();
          });
        }
        
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
          title: const Text('Statistiche e Grafici', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      _buildStatsTab(
                        title: 'Trend Sestina',
                        hotNumbers: _hotNumbers,
                        coldNumbers: _coldNumbers,
                      ),
                      _buildStatsTab(
                        title: 'Trend SuperStar',
                        hotNumbers: _ssHotNumbers.isNotEmpty ? _ssHotNumbers : _hotNumbers,
                        coldNumbers: _ssColdNumbers.isNotEmpty ? _ssColdNumbers : _coldNumbers,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatsTab({
    required String title,
    required List<int> hotNumbers,
    required List<int> coldNumbers,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aggiornato al: $_targetDate',
            style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          
          _buildChartSection(
            title: '🔥 Numeri Più Caldi (Top 10)',
            numbers: hotNumbers,
            color: Colors.redAccent,
          ),
          
          const SizedBox(height: 48),
          
          _buildChartSection(
            title: '❄️ Numeri Più Freddi (Top 10)',
            numbers: coldNumbers,
            color: Colors.lightBlueAccent,
          ),
          
          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'I grafici a barre mostrano la probabilità normalizzata calcolata dall\'IA per l\'estrazione corrente. Il picco massimo rappresenta il numero col punteggio più alto nel vettore di consenso.',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection({
    required String title,
    required List<int> numbers,
    required Color color,
  }) {
    if (numbers.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 24),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 1.0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${numbers[group.x.toInt()]}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      children: <TextSpan>[
                        TextSpan(
                          text: '${(rod.toY * 100).toStringAsFixed(1)}%',
                          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value.toInt() >= numbers.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          numbers[value.toInt()].toString(),
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(numbers.length, (index) {
                int number = numbers[index];
                double maxProb = _probabilities.values.isEmpty ? 1.0 : _probabilities.values.reduce((a, b) => a > b ? a : b);
                double rawProb = _probabilities[number] ?? 0.0;
                double normalizedY = maxProb > 0 ? (rawProb / maxProb) : 0.0;
                
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: normalizedY,
                      color: color,
                      width: 16,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
