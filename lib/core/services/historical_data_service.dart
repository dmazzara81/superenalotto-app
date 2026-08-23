import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ExtractionData {
  final String date;
  final List<int> numbers;
  final int jolly;
  final int superstar;
  final String? jackpot;

  ExtractionData({
    required this.date,
    required this.numbers,
    required this.jolly,
    required this.superstar,
    this.jackpot,
  });
}

class HistoricalDataService {
  static Future<ExtractionData?> fetchLatestExtraction() async {
    try {
      final response = await Supabase.instance.client
          .from('historical_extractions')
          .select()
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        String rawDate = response['date'] as String;
        // La data dal DB è in formato YYYY-MM-DD
        DateTime dateObj = DateTime.parse(rawDate);
        String formattedDate = DateFormat('dd/MM/yyyy').format(dateObj);
        
        List<int> nums = [
          response['n1'] as int,
          response['n2'] as int,
          response['n3'] as int,
          response['n4'] as int,
          response['n5'] as int,
          response['n6'] as int,
        ];
        
        return ExtractionData(
          date: formattedDate,
          numbers: nums,
          jolly: response['jolly'] as int,
          superstar: response['superstar'] as int,
          jackpot: response.containsKey('jackpot') ? response['jackpot'] as String? : null,
        );
      }
    } catch (e) {
      print('Errore fetch latest extraction from Supabase: $e');
    }
    return null;
  }
}
