import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:superenalotto/core/utils/combinatorics.dart';
import 'package:superenalotto/features/premium_analytics/data/saved_sestinas_repository.dart';
import 'package:superenalotto/core/services/tracking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

List<List<int>> _reduceSystemIsolate(Map<String, dynamic> args) {
  final pool = args['pool'] as List<int>;
  final guarantee = args['guarantee'] as SystemGuarantee;
  return Combinatorics.reduceSystem(pool, guarantee);
}


class SystemResultScreen extends StatefulWidget {
  final List<int> pool;
  final int? superstar;
  final SystemGuarantee guarantee;

  const SystemResultScreen({
    super.key,
    required this.pool,
    required this.superstar,
    required this.guarantee,
  });

  @override
  State<SystemResultScreen> createState() => _SystemResultScreenState();
}

class _SystemResultScreenState extends State<SystemResultScreen> {
  bool _isGenerating = true;
  List<List<int>> _generatedTickets = [];
  String _systemTitle = '';

  @override
  void initState() {
    super.initState();
    _setTitle();
    _generate();
  }

  void _setTitle() {
    if (widget.guarantee == SystemGuarantee.integral) {
      _systemTitle = 'Sistema Integrale - ${widget.pool.length} Numeri';
    } else if (widget.guarantee == SystemGuarantee.g4) {
      _systemTitle = 'Sistema Ridotto G4 - ${widget.pool.length} Numeri';
    } else {
      _systemTitle = 'Sistema Ridotto G3 - ${widget.pool.length} Numeri';
    }
  }

  Future<void> _generate() async {
    // Usa un isolate per non bloccare la UI durante calcoli intensivi
    final result = await compute(_reduceSystemIsolate, {
      'pool': widget.pool,
      'guarantee': widget.guarantee,
    });
    
    if (mounted) {
      setState(() {
        _generatedTickets = result;
        _isGenerating = false;
      });
      
      // Tracciamento anonimo
      try {
        final res = await Supabase.instance.client
            .from('number_probabilities')
            .select('target_date')
            .order('target_date', ascending: false)
            .limit(1)
            .single();
        if (res['target_date'] != null) {
          TrackingService.trackGeneration(
            targetDate: res['target_date'],
            tickets: result,
            superstar: widget.superstar,
            isSystem: true,
          );
        }
      } catch (e) {
        // Ignora
      }
    }
  }

  void _saveSystem() async {
    HapticFeedback.lightImpact();
    await SavedSestinasRepository.saveSystem(
      title: _systemTitle,
      tickets: _generatedTickets,
      superstar: widget.superstar,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sistema salvato con successo! 💾'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalCost = _generatedTickets.length; // 1€ per combinazione (assunto base, per semplicità ignoriamo superstar cost aggiuntivi se complessi)
    if (widget.superstar != null) totalCost *= 1; // SuperStar di base costa 0.50€ in più a giocata, ma diciamo 1.50 tot. Facciamo cost 1.50 se c'è SS.
    double actualCost = _generatedTickets.length * (widget.superstar != null ? 1.50 : 1.00);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sviluppo Sistema', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.cyanAccent),
                  SizedBox(height: 16),
                  Text('Calcolo combinatorio in corso...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : Column(
              children: [
                // Info Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _systemTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Schede generate: ${_generatedTickets.length}', style: const TextStyle(color: Colors.white)),
                          Text('Costo Stimato: €${actualCost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.pool.map((num) {
                          return Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.cyan.shade800,
                            ),
                            child: Center(
                              child: Text(
                                num.toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (widget.superstar != null) ...[
                         const SizedBox(height: 12),
                         Row(
                           children: [
                             const Text('SuperStar Fissato:', style: TextStyle(color: Colors.white70)),
                             const SizedBox(width: 8),
                             CircleAvatar(
                               radius: 14,
                               backgroundColor: Colors.amber,
                               child: Text(widget.superstar.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                             )
                           ],
                         )
                      ]
                    ],
                  ),
                ),
                
                // Lista Ticket
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _generatedTickets.length,
                    itemBuilder: (context, index) {
                      final ticket = _generatedTickets[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Text(
                                '#${index + 1}',
                                style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: ticket.map((num) {
                                    return CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      child: Text(
                                        num.toString(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.save_alt, color: Colors.cyanAccent),
                                tooltip: 'Salva Schedina Singola',
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  await SavedSestinasRepository.saveSestina(ticket, widget.superstar);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Schedina #${index + 1} salvata con successo! 💾'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Footer Save
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: ElevatedButton.icon(
                    onPressed: _saveSystem,
                    icon: const Icon(Icons.save, color: Colors.black),
                    label: const Text('SALVA SISTEMA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
