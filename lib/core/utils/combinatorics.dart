import 'dart:math';

enum SystemGuarantee {
  integral, // Tutte le combinazioni
  g4,       // Garanzia 4 se estratti 6 numeri dal pool
  g3,       // Garanzia 3 se estratti 6 numeri dal pool
}

class Combinatorics {
  /// Genera tutte le combinazioni di k elementi da una lista pool
  static List<List<int>> generateCombinations(List<int> pool, int k) {
    List<List<int>> result = [];
    _combinationsRecursive(pool, k, 0, [], result);
    return result;
  }

  static void _combinationsRecursive(
      List<int> pool, int k, int start, List<int> current, List<List<int>> result) {
    if (current.length == k) {
      result.add(List.from(current));
      return;
    }
    for (int i = start; i < pool.length; i++) {
      current.add(pool[i]);
      _combinationsRecursive(pool, k, i + 1, current, result);
      current.removeLast();
    }
  }

  /// Applica una riduzione greedy per garantire una determinata vincita minima.
  /// Il concetto: trovare il numero minimo di sestine (tra tutte quelle possibili)
  /// che copra tutti i bersagli possibili (tutte le sestine vincenti estraibili dal pool)
  /// con un'intersezione >= guarantee.
  static List<List<int>> reduceSystem(List<int> pool, SystemGuarantee guarantee) {
    List<List<int>> allCombinations = generateCombinations(pool, 6);
    
    if (guarantee == SystemGuarantee.integral) {
      return allCombinations;
    }

    int intersectionTarget = guarantee == SystemGuarantee.g4 ? 4 : 3;

    List<List<int>> targets = List.from(allCombinations); // Copia
    List<List<int>> candidates = List.from(allCombinations);
    List<List<int>> chosen = [];

    // Ottimizzazione: calcoliamo in anticipo le intersezioni
    // Per pool piccoli (<13), questo ciclo greedy impiega pochissimi millisecondi.
    while (targets.isNotEmpty) {
      int bestScore = -1;
      List<int> bestCandidate = [];
      List<List<int>> targetsCoveredByBest = [];

      for (var candidate in candidates) {
        int score = 0;
        List<List<int>> coveredByThis = [];
        for (var target in targets) {
          int intersection = _getIntersectionSize(candidate, target);
          if (intersection >= intersectionTarget) {
            score++;
            coveredByThis.add(target);
          }
        }

        if (score > bestScore) {
          bestScore = score;
          bestCandidate = candidate;
          targetsCoveredByBest = coveredByThis;
        }
      }

      chosen.add(bestCandidate);
      // Rimuovi i target coperti
      for (var t in targetsCoveredByBest) {
        targets.remove(t);
      }
      // Possiamo opzionalmente rimuovere il candidato scelto per non ripescarlo, 
      // sebbene il greedy non lo sceglierebbe comunque perché coprirebbe 0 nuovi target.
      candidates.remove(bestCandidate);
    }

    return chosen;
  }

  static int _getIntersectionSize(List<int> a, List<int> b) {
    int count = 0;
    int i = 0, j = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        count++;
        i++;
        j++;
      } else if (a[i] < b[j]) {
        i++;
      } else {
        j++;
      }
    }
    return count;
  }

  /// Sviluppa un sistema con Basi Fisse
  static List<List<int>> generateBasiVarianti(List<int> basi, List<int> varianti) {
    if (basi.isEmpty || basi.length >= 6) return [];
    
    int needed = 6 - basi.length;
    List<List<int>> combinations = generateCombinations(varianti, needed);
    
    List<List<int>> result = [];
    for (var comb in combinations) {
      List<int> full = List.from(basi)..addAll(comb);
      full.sort();
      result.add(full);
    }
    return result;
  }
}
