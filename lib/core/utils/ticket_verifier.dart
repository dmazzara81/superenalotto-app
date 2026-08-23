import 'package:superenalotto/core/services/historical_data_service.dart';

class TicketVerificationResult {
  final int matchedNumbersCount;
  final bool matchedSuperstar;
  final Set<int> matchedNumbers;
  final bool hasWon;
  final String winCategory;

  TicketVerificationResult({
    required this.matchedNumbersCount,
    required this.matchedSuperstar,
    required this.matchedNumbers,
    required this.hasWon,
    required this.winCategory,
  });
}

class TicketVerifier {
  /// Verifica una singola sestina contro l'estrazione data
  static TicketVerificationResult verifySestina({
    required List<int> sestina,
    required int? superstar,
    required ExtractionData extraction,
  }) {
    Set<int> ticketSet = sestina.toSet();
    Set<int> extractionSet = extraction.numbers.toSet();

    // Trova i numeri combacianti
    Set<int> matchedNumbers = ticketSet.intersection(extractionSet);
    
    // Controllo Jolly (per il 5+1)
    bool hasJolly = ticketSet.contains(extraction.jolly);
    
    // Controllo SuperStar
    bool matchedSuperstar = superstar != null && superstar == extraction.superstar;
    
    int count = matchedNumbers.length;
    
    bool hasWon = false;
    String category = '';
    
    if (count == 6) {
      hasWon = true;
      category = 'Punti 6';
    } else if (count == 5 && hasJolly) {
      hasWon = true;
      category = 'Punti 5+1';
      matchedNumbers.add(extraction.jolly); // Per evidenziarlo
    } else if (count == 5) {
      hasWon = true;
      category = 'Punti 5';
    } else if (count == 4) {
      hasWon = true;
      category = 'Punti 4';
    } else if (count == 3) {
      hasWon = true;
      category = 'Punti 3';
    } else if (count == 2) {
      hasWon = true;
      category = 'Punti 2';
    } else if (matchedSuperstar) {
      // Se non si fa 2, 3, 4, 5, 5+1, 6 ma si prende il SS
      if (count == 1) {
        hasWon = true;
        category = '1 Stella';
      } else if (count == 0) {
        hasWon = true;
        category = '0 Stella';
      }
    }
    
    // Aggiungi suffisso SuperStar per categorie superiori
    if (hasWon && matchedSuperstar && category.startsWith('Punti')) {
      category = '$category Stella';
    }

    return TicketVerificationResult(
      matchedNumbersCount: count,
      matchedSuperstar: matchedSuperstar,
      matchedNumbers: matchedNumbers,
      hasWon: hasWon,
      winCategory: category,
    );
  }
}
