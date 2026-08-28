import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:superenalotto/core/utils/combinatorics.dart';
import 'package:superenalotto/features/systems/domain/system_engine.dart';
import 'system_result_screen.dart';

class SystemsHubScreen extends StatefulWidget {
  const SystemsHubScreen({super.key});

  @override
  State<SystemsHubScreen> createState() => _SystemsHubScreenState();
}

class _SystemsHubScreenState extends State<SystemsHubScreen> {
  SystemType _systemType = SystemType.integral;
  SystemGuarantee _guarantee = SystemGuarantee.g3;
  
  int _targetNumbers = 7; 
  Set<int> _selectedNumbers = {};
  
  // Basi e Varianti
  Set<int> _basiNumbers = {};
  Set<int> _variantiNumbers = {};
  
  int? _selectedSuperstar;
  bool _isLoading = false;

  void _onTypeChanged(SystemType? val) {
    if (val == null) return;
    setState(() {
      _systemType = val;
      _selectedNumbers.clear();
      _basiNumbers.clear();
      _variantiNumbers.clear();
      
      if (_systemType == SystemType.integral) {
        _targetNumbers = 7;
      } else if (_systemType == SystemType.reduced) {
        _targetNumbers = 10;
      } else if (_systemType == SystemType.cruciverba) {
        _targetNumbers = 36;
      }
    });
  }
  
  void _onGuaranteeChanged(SystemGuarantee? val) {
    if (val == null) return;
    setState(() {
      _guarantee = val;
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

      List<int> sortedNumbers = consensusVector.keys.toList()
        ..sort((a, b) => consensusVector[b]!.compareTo(consensusVector[a]!));
        
      if (_systemType == SystemType.basiVarianti) {
          List<int> hotPool = sortedNumbers.take(15).toList();
          hotPool.shuffle();
          _basiNumbers = hotPool.take(2).toSet();
          _variantiNumbers = hotPool.skip(2).take(8).toSet();
      } else if (_systemType == SystemType.cruciverba) {
          List<int> hotPool = sortedNumbers.take(45).toList();
          hotPool.shuffle();
          _selectedNumbers = hotPool.take(36).toSet();
      } else {
          List<int> hotPool = sortedNumbers.take(30).toList();
          hotPool.shuffle();
          _selectedNumbers = hotPool.take(_targetNumbers).toSet();
      }
      
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
        List<int> hotSSPool = sortedSS.take(10).toList();
        hotSSPool.shuffle();
        ss = hotSSPool.first;
      }

      setState(() {
        _selectedSuperstar = ss;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore AI: '), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateSystem() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return SystemResultScreen(
            type: _systemType,
            pool: _selectedNumbers.toList()..sort(),
            basi: _basiNumbers.toList()..sort(),
            varianti: _variantiNumbers.toList()..sort(),
            superstar: _selectedSuperstar,
            guarantee: _guarantee,
          );
        }
      ),
    );
  }

  void _toggleNumber(int number) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_systemType == SystemType.basiVarianti) {
        if (_basiNumbers.contains(number)) {
          _basiNumbers.remove(number);
          _variantiNumbers.add(number);
        } else if (_variantiNumbers.contains(number)) {
          _variantiNumbers.remove(number);
        } else {
          if (_basiNumbers.length < 5) {
            _basiNumbers.add(number);
          } else {
            _variantiNumbers.add(number);
          }
        }
      } else {
        if (_selectedNumbers.contains(number)) {
          _selectedNumbers.remove(number);
        } else {
          if (_selectedNumbers.length < _targetNumbers) {
            _selectedNumbers.add(number);
          }
        }
      }
    });
  }
  
  bool _canGenerate() {
    if (_systemType == SystemType.basiVarianti) {
        return _basiNumbers.isNotEmpty && _variantiNumbers.length >= (6 - _basiNumbers.length);
    }
    return _selectedNumbers.length == _targetNumbers;
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
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tipologia di Sistema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          const SizedBox(height: 8),
                          RadioListTile<SystemType>(
                            title: const Text('Integrale', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('Sviluppa tutte le combinazioni possibili.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            value: SystemType.integral,
                            groupValue: _systemType,
                            activeColor: Colors.cyanAccent,
                            onChanged: _onTypeChanged,
                          ),
                          RadioListTile<SystemType>(
                            title: const Text('Ridotto', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('Garanzia di vincita minore con costo ridotto.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            value: SystemType.reduced,
                            groupValue: _systemType,
                            activeColor: Colors.cyanAccent,
                            onChanged: _onTypeChanged,
                          ),
                          RadioListTile<SystemType>(
                            title: const Text('Basi e Varianti', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('Numeri fissi in ogni schedina, mescolati con le varianti.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            value: SystemType.basiVarianti,
                            groupValue: _systemType,
                            activeColor: Colors.cyanAccent,
                            onChanged: _onTypeChanged,
                          ),
                          RadioListTile<SystemType>(
                            title: const Text('Cruciverba 6x6', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('36 numeri disposti in griglia.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            value: SystemType.cruciverba,
                            groupValue: _systemType,
                            activeColor: Colors.cyanAccent,
                            onChanged: _onTypeChanged,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_systemType == SystemType.reduced) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Garanzia del Ridotto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              RadioListTile<SystemGuarantee>(
                                title: const Text('Garanzia 4', style: TextStyle(color: Colors.white)),
                                value: SystemGuarantee.g4,
                                groupValue: _guarantee,
                                onChanged: _onGuaranteeChanged,
                                activeColor: Colors.cyanAccent,
                              ),
                              RadioListTile<SystemGuarantee>(
                                title: const Text('Garanzia 3', style: TextStyle(color: Colors.white)),
                                value: SystemGuarantee.g3,
                                groupValue: _guarantee,
                                onChanged: _onGuaranteeChanged,
                                activeColor: Colors.cyanAccent,
                              ),
                            ],
                          ),
                        )
                      )
                  ],
                  
                  if (_systemType != SystemType.basiVarianti && _systemType != SystemType.cruciverba) ...[
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Quanti numeri?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                              Text('', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent)),
                            ],
                          ),
                          Slider(
                            value: _targetNumbers.toDouble(),
                            min: 7,
                            max: _systemType == SystemType.integral ? 10 : 15,
                            divisions: _systemType == SystemType.integral ? 3 : 8,
                            activeColor: Colors.cyanAccent,
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
                  ],
                  const SizedBox(height: 16),

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
                  if (_systemType == SystemType.basiVarianti)
                    Text('Basi (Giallo): \/5 - Varianti (Azzurro): ', style: const TextStyle(color: Colors.white70))
                  else
                    Text('Selezionati: \ / ', style: const TextStyle(color: Colors.white70)),
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
                        bool isSelected = false;
                        bool isBase = false;
                        
                        if (_systemType == SystemType.basiVarianti) {
                            if (_basiNumbers.contains(number)) {
                                isSelected = true;
                                isBase = true;
                            } else if (_variantiNumbers.contains(number)) {
                                isSelected = true;
                            }
                        } else {
                            isSelected = _selectedNumbers.contains(number);
                        }
                        
                        Color bgColor = Colors.white;
                        if (isSelected) {
                            bgColor = isBase ? Colors.amber.shade600 : Colors.cyan.shade600;
                        }
                        
                        return GestureDetector(
                          onTap: () => _toggleNumber(number),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSelected ? (isBase ? Colors.amber.shade800 : Colors.cyan.shade800) : Colors.grey.shade300),
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
                  
                  // SuperStar (Omesso per brevità per Basi e varianti, ma si puo aggiungere)
                  if (_systemType != SystemType.cruciverba) ...[
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
                                const Text('Nessuno', style: TextStyle(color: Colors.white54)),
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
                                        onPressed: () => Navigator.pop(context, -1),
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
                  ],
                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    onPressed: _canGenerate() ? _generateSystem : null,
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
