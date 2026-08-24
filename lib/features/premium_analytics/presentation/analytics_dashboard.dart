import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:superenalotto/features/premium_analytics/data/saved_sestinas_repository.dart';
import 'package:superenalotto/features/premium_analytics/presentation/saved_sestinas_screen.dart';
import 'package:superenalotto/core/services/tracking_service.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  List<int> _currentSestina = [];
  int? _currentSuperStar;
  bool _isGenerating = false;
  String _errorMessage = '';
  
  final List<String> _availableModels = [
    'Ensemble (Consigliato)',
    'Markov_Chains',
    'Bayesian_Filters',
    'LSTM_Neural_Networks',
    'Genetic_Algorithms',
    'ARIMA_Time_Series',
    'Monte_Carlo_Simulations',
    'Random_Forest',
    'Hidden_Markov_Models',
    'Transformer_Attention'
  ];
  String _selectedModel = 'Ensemble (Consigliato)';
  
  Map<int, double>? _cachedProbabilities;

  @override
  void initState() {
    super.initState();
    _preloadProbabilities();
  }

  Future<void> _preloadProbabilities() async {
    try {
      final response = await Supabase.instance.client
          .from('number_probabilities')
          .select('probabilities')
          .order('target_date', ascending: false)
          .limit(1)
          .single();
          
      final Map<String, dynamic> rawConsensus = response['probabilities'];
      Map<int, double> consensusVector = {};
      rawConsensus.forEach((key, value) {
        consensusVector[int.parse(key)] = (value as num).toDouble();
      });
      setState(() {
        _cachedProbabilities = consensusVector;
      });
    } catch (e) {
      debugPrint("Preload error: $e");
    }
  }

  /// LOGICA SISTEMA 2 CON SUPABASE
  /// Estrae 6 numeri + 1 SuperStar basandosi sui pesi scaricati dal cloud
  /// Permette l'inserimento di numeri fissi (versione Ibrida)
  Future<void> _generateProSestina({Set<int>? lockedNumbers, int? lockedSuperStar}) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isGenerating = true;
      _errorMessage = '';
      _currentSestina = [];
      _currentSuperStar = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('number_probabilities')
          .select()
          .order('target_date', ascending: false)
          .limit(1)
          .single();

      final Map<String, dynamic> rawConsensus = response['probabilities'];
      final Map<String, dynamic>? rawSuperstarConsensus = response['superstar_probabilities'];
      final Map<String, dynamic>? individualModels = response['individual_models'];
      final String targetDate = response['target_date'] ?? '';
      
      Map<int, double> consensusVector = {};
      Map<String, dynamic> sourceProbabilities = rawConsensus;
      
      if (_selectedModel != 'Ensemble (Consigliato)' && individualModels != null) {
        if (individualModels.containsKey(_selectedModel)) {
          sourceProbabilities = individualModels[_selectedModel];
        }
      }
      
      sourceProbabilities.forEach((key, value) {
        consensusVector[int.parse(key)] = (value as num).toDouble();
      });
      
      Map<int, double> ssConsensusVector = {};
      if (rawSuperstarConsensus != null) {
        rawSuperstarConsensus.forEach((key, value) {
          ssConsensusVector[int.parse(key)] = (value as num).toDouble();
        });
      } else {
        ssConsensusVector = Map.from(consensusVector);
      }

      // 1. Estrazione Sestina
      double totalWeight = consensusVector.values.reduce((a, b) => a + b);
      Set<int> generatedNumbers = {};
      
      if (lockedNumbers != null) {
        generatedNumbers.addAll(lockedNumbers);
      }
      
      Random rand = Random();

      while (generatedNumbers.length < 6) {
        double randomValue = rand.nextDouble() * totalWeight;
        double cumulativeWeight = 0.0;

        for (var entry in consensusVector.entries) {
          cumulativeWeight += entry.value;
          if (randomValue <= cumulativeWeight) {
            if (!generatedNumbers.contains(entry.key)) {
               generatedNumbers.add(entry.key);
            }
            break; 
          }
        }
      }
      
      // 2. Estrazione SuperStar
      int? generatedSuperStar = lockedSuperStar;
      if (generatedSuperStar == null) {
        double totalWeightSS = ssConsensusVector.values.reduce((a, b) => a + b);
        double randomValueSS = rand.nextDouble() * totalWeightSS;
        double cumulativeWeightSS = 0.0;
        
        for (var entry in ssConsensusVector.entries) {
          cumulativeWeightSS += entry.value;
          if (randomValueSS <= cumulativeWeightSS) {
            generatedSuperStar = entry.key;
            break; 
          }
        }
      }

      setState(() {
        _currentSestina = generatedNumbers.toList()..sort();
        _currentSuperStar = generatedSuperStar ?? 1; // Fallback
      });

      // Tracciamento anonimo
      if (targetDate.isNotEmpty) {
        TrackingService.trackGeneration(
          targetDate: targetDate,
          tickets: [_currentSestina],
          superstar: _currentSuperStar,
          isSystem: false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Errore: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _openTermometroBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SchedinaBottomSheet(
        title: 'Termometro Sestina',
        description: 'Seleziona 6 numeri e 1 SuperStar per testare la tua combinazione.',
        mode: SchedinaMode.termometro,
        probabilities: _cachedProbabilities,
        onAnalyze: (sestina, superstar) {
          Navigator.pop(context);
          _showAnalysisResult(sestina, superstar);
        },
      ),
    );
  }

  void _openHybridGeneratorBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SchedinaBottomSheet(
        title: 'Generazione Ibrida',
        description: 'Blocca fino a 5 numeri base e/o 1 SuperStar. L\'IA farà il resto.',
        mode: SchedinaMode.ibrida,
        onGenerate: (sestina, superstar) {
          Navigator.pop(context);
          _generateProSestina(lockedNumbers: sestina, lockedSuperStar: superstar);
        },
      ),
    );
  }
  
  void _showAnalysisResult(Set<int> sestina, int? superstar) {
    if (sestina.length < 6 || _cachedProbabilities == null) return;
    
    // Calcolo Voto Base
    List<double> allProbs = _cachedProbabilities!.values.toList()..sort((a, b) => b.compareTo(a));
    double maxPossibleScore = allProbs.take(6).reduce((a, b) => a + b);
    double minPossibleScore = allProbs.reversed.take(6).reduce((a, b) => a + b);
    
    double userScore = 0;
    for (int num in sestina) {
      userScore += _cachedProbabilities![num] ?? 0;
    }
    
    double normalized = ((userScore - minPossibleScore) / (maxPossibleScore - minPossibleScore)) * 100;
    int finalScore = normalized.clamp(0, 100).toInt();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Risultato Analisi 🌡️', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Punteggio IA della tua Sestina:', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              '$finalScore / 100',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: finalScore > 70 ? Colors.greenAccent : (finalScore > 40 ? Colors.orangeAccent : Colors.redAccent),
              ),
            ),
            const SizedBox(height: 16),
            if (superstar != null) ...[
              const Text('SuperStar Selezionato:', style: TextStyle(color: Colors.white70)),
              Text(superstar.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
              const SizedBox(height: 16),
            ],
            Text(
              'Ottima scelta! Gioca la tua schedina fortunata, ma perché non raddoppiare le probabilità affiancandole anche una generata dalla nostra Intelligenza Artificiale?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CAPITO', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ensemble Analytics (PRO)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.amber),
            tooltip: 'Le Mie Schedine',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedSestinasScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Introduttiva
            Card(
              elevation: 8,
              shadowColor: Theme.of(context).primaryColor.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.psychology, size: 48, color: Colors.amber),
                    const SizedBox(height: 12),
                    Text(
                      'Generatore Quantico',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scarica i pesi dinamici aggiornati dal Cloud (Supabase).',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Termometro Sestina (Pulsante secondario)
            OutlinedButton.icon(
              onPressed: _openTermometroBottomSheet,
              icon: const Icon(Icons.thermostat, color: Colors.cyanAccent),
              label: const Text('Analizza la tua Schedina', style: TextStyle(color: Colors.cyanAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.cyanAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // Messaggio di Errore
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            // Display della Sestina + SuperStar (Glassmorphism)
            Expanded(
              child: ClipRRect(
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
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          blurRadius: 30,
                          spreadRadius: -5,
                        )
                      ]
                    ),
                    child: _isGenerating
                        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                        : _currentSestina.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nessuna sestina generata.\nPremi un pulsante qui sotto.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 16,
                                    children: _currentSestina.map((num) {
                                      return Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Colors.white, Color(0xFFE0E0E0)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        ),
                                        child: Center(
                                          child: Text(
                                            num.toString(),
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 36),
                                  if (_currentSuperStar != null)
                                    Column(
                                      children: [
                                        const Text('SUPERSTAR', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                                        const SizedBox(height: 12),
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [Colors.amberAccent, Colors.orange],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.withOpacity(0.6),
                                                blurRadius: 20,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          ),
                                          child: Center(
                                            child: Text(
                                              _currentSuperStar.toString(),
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 24),
                                  // Pulsante Salva
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      HapticFeedback.lightImpact();
                                      await SavedSestinasRepository.saveSestina(_currentSestina, _currentSuperStar);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Schedina salvata con successo! 💾'),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                          )
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.save, color: Colors.white),
                                    label: const Text('SALVA SCHEDINA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.white54),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Selezione Modello IA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedModel,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedModel = newValue;
                      });
                    }
                  },
                  items: _availableModels.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.replaceAll('_', ' ')),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pulsanti Generazione
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () => _generateProSestina(),
                    icon: const Icon(Icons.bolt, color: Colors.black),
                    label: const Text('AUTO 100%', style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _openHybridGeneratorBottomSheet,
                    icon: const Icon(Icons.handshake, color: Colors.white),
                    label: const Text('IBRIDA', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// SCHEDINA REALISTICA (BOTTOM SHEET)
// =====================================================================
enum SchedinaMode { termometro, ibrida }

class SchedinaBottomSheet extends StatefulWidget {
  final String title;
  final String description;
  final SchedinaMode mode;
  final Map<int, double>? probabilities;
  final Function(Set<int> sestina, int? superstar)? onAnalyze;
  final Function(Set<int> sestina, int? superstar)? onGenerate;

  const SchedinaBottomSheet({
    super.key,
    required this.title,
    required this.description,
    required this.mode,
    this.probabilities,
    this.onAnalyze,
    this.onGenerate,
  });

  @override
  State<SchedinaBottomSheet> createState() => _SchedinaBottomSheetState();
}

class _SchedinaBottomSheetState extends State<SchedinaBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<int> _selectedSestina = {};
  int? _selectedSuperstar;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSestinaNumber(int number) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedSestina.contains(number)) {
        _selectedSestina.remove(number);
      } else {
        int limit = widget.mode == SchedinaMode.termometro ? 6 : 5;
        if (_selectedSestina.length < limit) {
          _selectedSestina.add(number);
        }
      }
    });
  }

  void _toggleSuperstarNumber(int number) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedSuperstar == number) {
        _selectedSuperstar = null;
      } else {
        _selectedSuperstar = number;
      }
    });
  }

  bool _isActionEnabled() {
    if (widget.mode == SchedinaMode.termometro) {
      return _selectedSestina.length == 6 && widget.probabilities != null;
    }
    return true; // Ibrida allows 0-5
  }

  void _handleAction() {
    HapticFeedback.heavyImpact();
    if (widget.mode == SchedinaMode.termometro) {
      widget.onAnalyze?.call(_selectedSestina, _selectedSuperstar);
    } else {
      widget.onGenerate?.call(_selectedSestina, _selectedSuperstar);
    }
  }

  Widget _buildGrid(bool isSuperstar) {
    return Container(
      color: const Color(0xFFF0F0F0), // Sfondo tipo schedina di carta
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 90,
        itemBuilder: (context, index) {
          int number = index + 1;
          bool isSelected = isSuperstar ? _selectedSuperstar == number : _selectedSestina.contains(number);
          
          return GestureDetector(
            onTap: () => isSuperstar ? _toggleSuperstarNumber(number) : _toggleSestinaNumber(number),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                      ? (isSuperstar ? Colors.amber : Colors.black) 
                      : Colors.grey.shade300,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: (isSuperstar ? Colors.amber : Colors.black).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ] : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    number.toString(),
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.close,
                      color: isSuperstar ? Colors.amber.shade700.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                      size: 36,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int maxSestina = widget.mode == SchedinaMode.termometro ? 6 : 5;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white, // Sfondo bianco della schedina
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context)
                    ),
                  ],
                ),
                Text(widget.description, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          
          // TabBar
          Material(
            color: Theme.of(context).primaryColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber,
              indicatorWeight: 4,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'SESTINA BASE'),
                Tab(text: 'SUPERSTAR'),
              ],
            ),
          ),
          
          // Grids
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(false), // Sestina
                _buildGrid(true),  // SuperStar
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Numeri: ${_selectedSestina.length} / $maxSestina', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    Text('SuperStar: ${_selectedSuperstar != null ? 1 : 0} / 1', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isActionEnabled() ? _handleAction : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.mode == SchedinaMode.termometro ? Colors.cyan.shade600 : Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      widget.mode == SchedinaMode.termometro 
                          ? 'ANALIZZA SCHEDINA'
                          : (_selectedSestina.isEmpty && _selectedSuperstar == null ? 'LASCIA FARE TUTTO ALL\'IA' : 'COMPLETA CON L\'IA'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
