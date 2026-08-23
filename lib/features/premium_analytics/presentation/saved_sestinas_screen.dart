import 'package:flutter/material.dart';
import 'package:superenalotto/features/premium_analytics/data/saved_sestinas_repository.dart';
import 'package:intl/intl.dart';
import 'package:superenalotto/core/services/historical_data_service.dart';
import 'package:superenalotto/core/utils/ticket_verifier.dart';

class SavedSestinasScreen extends StatefulWidget {
  const SavedSestinasScreen({super.key});

  @override
  State<SavedSestinasScreen> createState() => _SavedSestinasScreenState();
}

class _SavedSestinasScreenState extends State<SavedSestinasScreen> {
  List<Map<String, dynamic>> _savedSestinas = [];
  List<Map<String, dynamic>> _savedSystems = [];
  bool _isLoading = true;
  bool _isVerifying = false;
  
  // Mappa indice sestina -> Risultato verifica
  final Map<int, TicketVerificationResult> _sestinaResults = {};
  // Mappa indice sistema -> Lista risultati verifica per ogni giocata
  final Map<int, List<TicketVerificationResult>> _systemResults = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final sestinas = await SavedSestinasRepository.loadSestinas();
    final systems = await SavedSestinasRepository.loadSystems();
    setState(() {
      _savedSestinas = sestinas;
      _savedSystems = systems;
      _isLoading = false;
    });
  }

  Future<void> _deleteSestina(int index) async {
    await SavedSestinasRepository.deleteSestina(index);
    _loadData();
  }

  Future<void> _deleteSystem(int index) async {
    await SavedSestinasRepository.deleteSystem(index);
    _loadData();
  }

  Future<void> _verifyTickets() async {
    setState(() => _isVerifying = true);
    try {
      final extraction = await HistoricalDataService.fetchLatestExtraction();
      if (extraction == null) return; // Errore o non disponibile

      _sestinaResults.clear();
      _systemResults.clear();

      // Verifica Sestine
      for (int i = 0; i < _savedSestinas.length; i++) {
        final item = _savedSestinas[i];
        final List<int> sestina = List<int>.from(item['sestina']);
        final int? superstar = item['superstar'];
        
        final res = TicketVerifier.verifySestina(
          sestina: sestina,
          superstar: superstar,
          extraction: extraction,
        );
        if (res.hasWon) {
          _sestinaResults[i] = res;
        }
      }

      // Verifica Sistemi
      for (int i = 0; i < _savedSystems.length; i++) {
        final item = _savedSystems[i];
        final List<dynamic> ticketsDynamic = item['tickets'];
        final int? superstar = item['superstar'];
        
        List<TicketVerificationResult> sysResults = [];
        for (var t in ticketsDynamic) {
          final res = TicketVerifier.verifySestina(
            sestina: List<int>.from(t),
            superstar: superstar,
            extraction: extraction,
          );
          sysResults.add(res);
        }
        
        if (sysResults.any((r) => r.hasWon)) {
          _systemResults[i] = sysResults;
        }
      }

      if (_sestinaResults.isNotEmpty || _systemResults.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hai delle schedine vincenti! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nessuna vincita in base all\'ultima estrazione. Ritenta!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Errore verifica: $e");
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Archivio Giocate', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).primaryColor,
          actions: [
            if (!_isLoading && (_savedSestinas.isNotEmpty || _savedSystems.isNotEmpty))
              TextButton.icon(
                onPressed: _isVerifying ? null : _verifyTickets,
                icon: _isVerifying 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent))
                  : const Icon(Icons.verified, color: Colors.greenAccent),
                label: const Text('VERIFICA VINCITE', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              )
          ],
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'SESTINE'),
              Tab(text: 'SISTEMI'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : TabBarView(
                children: [
                  _buildSestinasTab(),
                  _buildSystemsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildSestinasTab() {
    if (_savedSestinas.isEmpty) {
      return _buildEmptyState('Nessuna sestina salvata.', 'Genera una sestina e clicca "Salva Schedina".');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedSestinas.length,
      itemBuilder: (context, index) {
        final item = _savedSestinas[index];
        final List<int> sestina = List<int>.from(item['sestina']);
        final int? superstar = item['superstar'];
        final DateTime date = DateTime.parse(item['date']);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Generata il: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteSestina(index),
                      tooltip: 'Elimina',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sestina.map((num) {
                    return CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white10,
                      child: Text(num.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    );
                  }).toList(),
                ),
                if (superstar != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('SUPERSTAR: ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _sestinaResults.containsKey(index) && _sestinaResults[index]!.matchedSuperstar 
                          ? Colors.greenAccent 
                          : Colors.amber,
                        child: Text(superstar.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                    ],
                  ),
                ],
                if (_sestinaResults.containsKey(index)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.greenAccent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stars, color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Hai vinto: ${_sestinaResults[index]!.winCategory}!',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemsTab() {
    if (_savedSystems.isEmpty) {
      return _buildEmptyState('Nessun sistema salvato.', 'Esplora i Sistemi Quantistici per iniziare.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedSystems.length,
      itemBuilder: (context, index) {
        final item = _savedSystems[index];
        final String title = item['title'];
        final List<dynamic> ticketsDynamic = item['tickets'];
        final int? superstar = item['superstar'];
        final DateTime date = DateTime.parse(item['date']);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          color: Theme.of(context).colorScheme.surface,
          child: ExpansionTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            subtitle: Text('Generato il: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white54,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (superstar != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            const Text('SUPERSTAR FISSO: ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.amber,
                              child: Text(superstar.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                            ),
                          ],
                        ),
                      ),
                    Text('Schede totali: ${ticketsDynamic.length}', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    ...ticketsDynamic.asMap().entries.map((entry) {
                      int tIdx = entry.key;
                      List<int> tNums = List<int>.from(entry.value);
                      final hasResult = _systemResults.containsKey(index);
                      final tRes = hasResult ? _systemResults[index]![tIdx] : null;
                      final bool isWin = tRes != null && tRes.hasWon;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Text('#${tIdx + 1}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                children: tNums.map((n) {
                                  bool isMatched = isWin && tRes.matchedNumbers.contains(n);
                                  return Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isMatched ? Colors.greenAccent.withOpacity(0.3) : Colors.white10,
                                      border: isMatched ? Border.all(color: Colors.greenAccent) : null,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(n.toString(), style: TextStyle(fontSize: 11, color: isMatched ? Colors.greenAccent : Colors.white, fontWeight: isMatched ? FontWeight.bold : FontWeight.normal)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            if (isWin)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(tRes.winCategory, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _deleteSystem(index),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('ELIMINA SISTEMA', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hub_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.white54)),
        ],
      ),
    );
  }
}
