import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:superenalotto/core/utils/combinatorics.dart';
import 'system_result_screen.dart';

class SystemsHubScreen extends StatefulWidget {
  const SystemsHubScreen({super.key});

  @override
  State<SystemsHubScreen> createState() => _SystemsHubScreenState();
}

class _SystemsHubScreenState extends State<SystemsHubScreen> {
  SystemGuarantee _guarantee = SystemGuarantee.integral;
  int _targetNumbers = 7; // da 7 a 15 dipendendo dal tipo
  Set<int> _selectedNumbers = {};
  int? _selectedSuperstar;
  bool _isLoading = false;

  void _onGuaranteeChanged(SystemGuarantee? val) {
    if (val == null) return;
    setState(() {
      _guarantee = val;
      // Adjust target numbers based on guarantee limits
      if (_guarantee == SystemGuarantee.integral && _targetNumbers > 10) {
        _targetNumbers = 10;
      }
      if (_guarantee != SystemGuarantee.integral && _targetNumbers < 9) {
        _targetNumbers = 9;
      }
      // Trim selected numbers if they exceed the new target
      if (_selectedNumbers.length > _targetNumbers) {
        _selectedNumbers = _selectedNumbers.take(_targetNumbers).toSet();
      }
    });
  }

  Future<void> _autoFillWithAI() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('number_probabilities')
          .select('probabilities, superstar_probabilities')
          .order('target_date', ascending: false)
          .limit(1)
          .single();

      final Map<String, dynamic> rawConsensus = response['probabilities'];
      Map<int, double> consensusVector = {};
      rawConsensus.forEach((key, value) {
        consensusVector[int.parse(key)] = (value as num).toDouble();
      });

      // Sort by highest probability
      List<int> sortedNumbers = consensusVector.keys.toList()
        ..sort((a, b) => consensusVector[b]!.compareTo(consensusVector[a]!));

      // Pick top _targetNumbers
      Set<int> newSelection = sortedNumbers.take(_targetNumbers).toSet();
      
      // Auto-pick SuperStar
      int ss = _selectedSuperstar ?? 1;
      if (response['superstar_probabilities'] != null) {
        final Map<String, dynamic> rawSS = response['superstar_probabilities'];
        Map<int, double> ssVector = {};
        rawSS.forEach((key, value) {
          ssVector[int.parse(key)] = (value as num).toDouble();
        });
        List<int> sortedSS = ssVector.keys.toList()
          ..sort((a, b) => ssVector[b]!.compareTo(ssVector[a]!));
        ss = sortedSS.first;
      }

      setState(() {
        _selectedNumbers = newSelection;
        _selectedSuperstar = ss;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore AI: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateSystem() {
    if (_selectedNumbers.length < _targetNumbers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seleziona $_targetNumbers numeri per procedere.'), backgroundColor: Colors.orange),
      );
      return;
    }

    HapticFeedback.lightImpact();
    // Naviga alla result screen passando i parametri
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SystemResultScreen(
          pool: _selectedNumbers.toList()..sort(),
          superstar: _selectedSuperstar,
          guarantee: _guarantee,
        ),
      ),
    );
  }

  void _toggleNumber(int number) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedNumbers.contains(number)) {
        _selectedNumbers.remove(number);
      } else {
        if (_selectedNumbers.length < _targetNumbers) {
          _selectedNumbers.add(number);
        }
      }
    });
  }

  Future<void> _pickSuperstar() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Scegli SuperStar', style: TextStyle(color: Colors.amber)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 90,
              itemBuilder: (context, index) {
                int num = index + 1;
                return InkWell(
                  onTap: () => Navigator.pop(context, num),
                  child: CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Text(num.toString(), style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null), // clear
              child: const Text('Rimuovi', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (selected != null || (selected == null && ModalRoute.of(context)?.isCurrent != true)) {
      // Se selected == null e il dialog è stato chiuso con 'Rimuovi', allora resettiamo
      // Ma showDialog restituisce null sia per Rimuovi (passato esplicitamente come null) che per back button/tap fuori (implicitamente null).
      // Usiamo una logica più semplice:
    }
    
    // Per gestire il Rimuovi propriamente:
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistemi Quantistici', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tipo di Garanzia
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tipo di Sistema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          const SizedBox(height: 8),
                          RadioListTile<SystemGuarantee>(
                            title: const Text('Integrale', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('Massima probabilità. Fino a 10 numeri.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            value: SystemGuarantee.integral,
                            groupValue: _guarantee,
                            activeColor: Colors.cyanAccent,
                            onChanged: _onGuaranteeChanged,
                          ),
                          RadioListTile<SystemGuarantee>(
                            title: const Text('Ridotto: Garanzia 4', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('Ottimo compromesso costi/benefici. Da 9 a 15 numeri.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            value: SystemGuarantee.g4,
                            groupValue: _guarantee,
                            activeColor: Colors.cyanAccent,
                            onChanged: _onGuaranteeChanged,
                          ),
                          RadioListTile<SystemGuarantee>(
                            title: const Text('Ridotto: Garanzia 3', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('Costo minimo per esplorare tanti numeri. Da 9 a 15 numeri.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            value: SystemGuarantee.g3,
                            groupValue: _guarantee,
                            activeColor: Colors.cyanAccent,
                            onChanged: _onGuaranteeChanged,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Slider per numero di numeri
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Numeri da giocare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                              Text('$_targetNumbers', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.cyanAccent)),
                            ],
                          ),
                          Slider(
                            value: _targetNumbers.toDouble(),
                            min: _guarantee == SystemGuarantee.integral ? 7 : 9,
                            max: _guarantee == SystemGuarantee.integral ? 10 : 15,
                            divisions: _guarantee == SystemGuarantee.integral ? 3 : 6,
                            activeColor: Colors.cyanAccent,
                            label: _targetNumbers.toString(),
                            onChanged: (val) {
                              setState(() {
                                _targetNumbers = val.toInt();
                                if (_selectedNumbers.length > _targetNumbers) {
                                  _selectedNumbers = _selectedNumbers.take(_targetNumbers).toSet();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Griglia di Selezione
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Scegli i numeri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                      TextButton.icon(
                        onPressed: _autoFillWithAI,
                        icon: const Icon(Icons.psychology, color: Colors.amber),
                        label: const Text('Usa AI', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Selezionati: ${_selectedNumbers.length} / $_targetNumbers', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: 90,
                      itemBuilder: (context, index) {
                        int number = index + 1;
                        bool isSelected = _selectedNumbers.contains(number);
                        return GestureDetector(
                          onTap: () => _toggleNumber(number),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.cyan.shade600 : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSelected ? Colors.cyan.shade800 : Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                number.toString(),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // SuperStar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('SuperStar (Opzionale):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          const SizedBox(width: 16),
                          if (_selectedSuperstar != null)
                            CircleAvatar(
                              backgroundColor: Colors.amber,
                              child: Text(_selectedSuperstar.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            )
                          else
                            const Text('Non scelto', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                      TextButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final selected = await showDialog<int?>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Scegli SuperStar', style: TextStyle(color: Colors.amber)),
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: 300,
                                  child: GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 6,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: 90,
                                    itemBuilder: (context, index) {
                                      int num = index + 1;
                                      return InkWell(
                                        onTap: () => Navigator.pop(context, num),
                                        child: CircleAvatar(
                                          backgroundColor: _selectedSuperstar == num ? Colors.amber : Colors.white10,
                                          child: Text(num.toString(), style: TextStyle(color: _selectedSuperstar == num ? Colors.black : Colors.white)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, -1), // Usa -1 come segnale per rimuovere
                                    child: const Text('Rimuovi', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Annulla', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              );
                            }
                          );

                          if (selected != null) {
                            setState(() {
                              if (selected == -1) {
                                _selectedSuperstar = null;
                              } else {
                                _selectedSuperstar = selected;
                              }
                            });
                          }
                        },
                        child: const Text('SCEGLI', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Generate Button
                  ElevatedButton.icon(
                    onPressed: _selectedNumbers.length == _targetNumbers ? _generateSystem : null,
                    icon: const Icon(Icons.hub, color: Colors.white),
                    label: const Text('ELABORA SISTEMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
