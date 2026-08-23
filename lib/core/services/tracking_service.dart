import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class TrackingService {
  /// Registra anonimamente una giocata nel cloud.
  static Future<void> trackGeneration({
    required String targetDate,
    required List<List<int>> tickets,
    int? superstar,
    required bool isSystem,
  }) async {
    try {
      // Invia in background senza attendere la risposta o mostrare errori bloccanti all'utente
      await Supabase.instance.client.from('ai_global_generations').insert({
        'target_date': targetDate,
        'sestine': tickets, // Supabase supporta nativamente l'inserimento di array JSON/text
        'superstar': superstar,
        'is_system': isSystem,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint("Tracking effettuato con successo per $targetDate");
    } catch (e) {
      // Catturiamo gli errori silenziosamente per non influenzare l'esperienza dell'utente
      debugPrint("Errore nel tracking globale: $e");
    }
  }
}
