import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedSestinasRepository {
  static const String _key = 'saved_sestinas';
  static const String _systemsKey = 'saved_systems';

  // Salva una nuova sestina
  static Future<void> saveSestina(List<int> sestina, int? superstar) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_key) ?? [];
    
    final newItem = {
      'sestina': sestina,
      'superstar': superstar,
      'date': DateTime.now().toIso8601String(),
    };
    
    saved.add(jsonEncode(newItem));
    await prefs.setStringList(_key, saved);
  }

  // Carica tutte le sestine
  static Future<List<Map<String, dynamic>>> loadSestinas() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_key) ?? [];
    
    List<Map<String, dynamic>> results = [];
    for (String item in saved) {
      try {
        results.add(jsonDecode(item) as Map<String, dynamic>);
      } catch (e) {
        // Ignora elementi corrotti
      }
    }
    
    // Ordina dalla più recente alla più vecchia
    results.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    return results;
  }

  // Elimina una sestina
  static Future<void> deleteSestina(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_key) ?? [];
    
    List<Map<String, dynamic>> current = await loadSestinas();
    if (index >= 0 && index < current.length) {
      current.removeAt(index);
      
      List<String> newSaved = current.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList(_key, newSaved);
    }
  }

  // --- GESTIONE SISTEMI ---

  static Future<void> saveSystem({
    required String title,
    required List<List<int>> tickets,
    required int? superstar,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_systemsKey) ?? [];
    
    final newItem = {
      'title': title,
      'tickets': tickets,
      'superstar': superstar,
      'date': DateTime.now().toIso8601String(),
    };
    
    saved.add(jsonEncode(newItem));
    await prefs.setStringList(_systemsKey, saved);
  }

  static Future<List<Map<String, dynamic>>> loadSystems() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_systemsKey) ?? [];
    
    List<Map<String, dynamic>> results = [];
    for (String item in saved) {
      try {
        results.add(jsonDecode(item) as Map<String, dynamic>);
      } catch (e) {
        // Ignora elementi corrotti
      }
    }
    
    results.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    return results;
  }

  static Future<void> deleteSystem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> current = await loadSystems();
    if (index >= 0 && index < current.length) {
      current.removeAt(index);
      List<String> newSaved = current.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList(_systemsKey, newSaved);
    }
  }
}
