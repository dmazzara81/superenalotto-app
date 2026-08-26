import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:superenalotto/core/services/historical_data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate; // Callback per navigare ad altri tab
  
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _timer;
  Duration _timeUntilNextDraw = Duration.zero;
  ExtractionData? _latestExtraction;
  bool _isLoadingExtraction = true;
  
  Map<String, dynamic>? _globalWinStats;
  
  List<Map<String, dynamic>> _currentStats = [];

  @override
  void initState() {
    super.initState();
    _fetchCuriosities();
    _calculateNextDraw();
    _fetchExtraction();
    _fetchGlobalStats();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateNextDraw();
    });
  }

  Future<void> _fetchGlobalStats() async {
    try {
      final res = await Supabase.instance.client
          .from('global_win_stats')
          .select()
          .order('draw_date', ascending: false)
          .limit(1)
          .single();
      if (mounted) {
        setState(() => _globalWinStats = res);
      }
    } catch (e) {
      // Ignora, non mostriamo nulla se fallisce
    }
  }

  Future<void> _fetchCuriosities() async {
    try {
      final res = await Supabase.instance.client
          .from('daily_curiosities')
          .select()
          .order('created_at', ascending: false)
          .limit(15);
      
      List<Map<String, dynamic>> fetched = [];
      for (var item in res) {
        String hexColor = item['color_hex'] ?? '#448AFF';
        hexColor = hexColor.replaceAll('#', '');
        if (hexColor.length == 6) hexColor = 'FF$hexColor';
        Color color = Color(int.parse(hexColor, radix: 16));
        
        fetched.add({
          'title': item['title'] ?? 'Curiosità',
          'description': item['description'] ?? '',
          'color': color,
          'icon': Icons.auto_awesome,
        });
      }
      
      if (mounted) {
        setState(() {
          fetched.shuffle();
          if (fetched.isEmpty) {
            // Fallback se il database è vuoto
            _currentStats = [
              {
                'title': '⏳ In Attesa',
                'description': 'Le curiosità di oggi stanno per essere generate dall\'IA. Torna più tardi!',
                'color': Colors.blueGrey,
                'icon': Icons.hourglass_empty
              },
              {
                'title': '🔮 Previsioni',
                'description': 'Il motore Quantico sta elaborando le nuove estrazioni...',
                'color': Colors.amber,
                'icon': Icons.psychology
              }
            ];
          } else {
            _currentStats = fetched.take(10).toList();
          }
        });
      }
    } catch (e) {
      debugPrint("Errore fetch curiosities: $e");
      if (mounted) {
        setState(() {
          _currentStats = [
            {
              'title': '⚠️ Errore Rete',
              'description': 'Non è stato possibile caricare le curiosità.',
              'color': Colors.redAccent,
              'icon': Icons.error_outline
            }
          ];
        });
      }
    }
  }

  Future<void> _fetchExtraction() async {
    final data = await HistoricalDataService.fetchLatestExtraction();
    if (mounted) {
      setState(() {
        _latestExtraction = data;
        _isLoadingExtraction = false;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _calculateNextDraw() {
    final now = DateTime.now();
    // Estrazioni: Martedì(2), Giovedì(4), Venerdì(5), Sabato(6) alle 20:00
    List<int> drawDays = [DateTime.tuesday, DateTime.thursday, DateTime.friday, DateTime.saturday];
    
    DateTime nextDraw = DateTime(now.year, now.month, now.day, 20, 0);
    
    // Se oggi è giorno di estrazione e sono passate le 20:00, o non è giorno di estrazione
    if ((drawDays.contains(now.weekday) && now.hour >= 20) || !drawDays.contains(now.weekday)) {
      int daysToAdd = 1;
      while (true) {
        DateTime checkDate = now.add(Duration(days: daysToAdd));
        if (drawDays.contains(checkDate.weekday)) {
          nextDraw = DateTime(checkDate.year, checkDate.month, checkDate.day, 20, 0);
          break;
        }
        daysToAdd++;
      }
    }

    setState(() {
      _timeUntilNextDraw = nextDraw.difference(now);
    });
  }

  String _formatDuration(Duration d) {
    String days = d.inDays > 0 ? '${d.inDays}g ' : '';
    String hours = (d.inHours % 24).toString().padLeft(2, '0');
    String minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$days$hours:$minutes:$seconds';
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchCuriosities(),
      _fetchExtraction(),
      _fetchGlobalStats(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).primaryColor.withOpacity(0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            color: Colors.amber,
            backgroundColor: const Color(0xFF1E1E2C),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const SizedBox(height: 20),
                // Hero Section
                Text(
                  'Bentornato!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sei pronto per la prossima estrazione?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 32),

                // Countdown Card (Glassmorphism)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: -5,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.timer_outlined, color: Colors.amber, size: 28),
                              SizedBox(width: 12),
                              Text(
                                'PROSSIMA ESTRAZIONE',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _formatDuration(_timeUntilNextDraw),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Bacheca Vittorie
                if (_globalWinStats != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade900, Colors.orange.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events, color: Colors.white, size: 28),
                            SizedBox(width: 8),
                            Text('Bacheca Vittorie IA', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nella data ${_globalWinStats!['draw_date']} i nostri utenti hanno generato e vinto:',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            if ((_globalWinStats!['total_3'] ?? 0) > 0) _buildStatBadge('Punti 3', _globalWinStats!['total_3']),
                            if ((_globalWinStats!['total_4'] ?? 0) > 0) _buildStatBadge('Punti 4', _globalWinStats!['total_4']),
                            if ((_globalWinStats!['total_5'] ?? 0) > 0) _buildStatBadge('Punti 5', _globalWinStats!['total_5']),
                            if ((_globalWinStats!['total_6'] ?? 0) > 0) _buildStatBadge('Punti 6', _globalWinStats!['total_6']),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Ultima Estrazione
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ultima Estrazione',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    if (_latestExtraction != null)
                      Text(
                        _latestExtraction!.date,
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _isLoadingExtraction
                    ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                    : _latestExtraction == null
                        ? const Center(child: Text('Errore di connessione', style: TextStyle(color: Colors.redAccent)))
                        : Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: _latestExtraction!.numbers.map((num) {
                                    return CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      child: Text(
                                        num.toString(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('JOLLY: ', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                                      child: Text(_latestExtraction!.jolly.toString(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 24),
                                    const Text('SUPERSTAR: ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.amber,
                                      child: Text(_latestExtraction!.superstar.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                if (_latestExtraction!.jackpot != null) ...[
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                                        const SizedBox(width: 8),
                                        const Text('JACKPOT IN PALIO: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _latestExtraction!.jackpot!,
                                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 20),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                const SizedBox(height: 40),

                // Sezione Carosello Statistiche & Curiosità
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Curiosità & Statistiche',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    Icon(Icons.swipe, color: Colors.white54, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    itemCount: _currentStats.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final stat = _currentStats[index];
                      return _buildCarouselCard(
                        context,
                        title: stat['title'],
                        description: stat['description'],
                        color: stat['color'],
                        icon: stat['icon'],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),

                // Quick Actions
                Text(
                  'Azioni Rapide',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        context,
                        title: 'Statistiche',
                        icon: Icons.bar_chart,
                        color: Colors.blueAccent,
                        onTap: () => widget.onNavigate(1), // Tab Stats
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildQuickActionCard(
                        context,
                        title: 'IA Ensemble',
                        icon: Icons.psychology,
                        color: Colors.amber,
                        isPro: true,
                        onTap: () => widget.onNavigate(2), // Tab Analytics
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildStatBadge(String title, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPro = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: isPro ? Border.all(color: Colors.amber.withOpacity(0.5), width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                if (isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselCard(BuildContext context, {
    required String title,
    required String description,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
