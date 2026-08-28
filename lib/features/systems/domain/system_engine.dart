import 'dart:math';
import 'package:superenalotto/core/utils/combinatorics.dart';

enum SystemType {
  integral,
  reduced,
  basiVarianti,
  cruciverba,
}

class SystemEngine {
  /// Genera un sistema tramite isolato
  static List<List<int>> generateSystem(Map<String, dynamic> args) {
    final type = args['type'] as SystemType;
    
    switch (type) {
      case SystemType.integral:
        return Combinatorics.generateCombinations(args['pool'] as List<int>, 6);
      case SystemType.reduced:
        return Combinatorics.reduceSystem(args['pool'] as List<int>, args['guarantee'] as SystemGuarantee);
      case SystemType.basiVarianti:
        return Combinatorics.generateBasiVarianti(args['basi'] as List<int>, args['varianti'] as List<int>);
      case SystemType.cruciverba:
        return generateCruciverba(args['pool'] as List<int>);
    }
  }

  /// Genera un sistema a Cruciverba (es. griglia 6x6 = 36 numeri -> 12 sestine)
  static List<List<int>> generateCruciverba(List<int> pool) {
    // Un vero cruciverba SuperEnalotto usa rettangoli dove le righe o colonne misurano 6.
    // L'implementazione base: se la griglia è Nx6, estraiamo le N righe e le 6 colonne.
    // Costruiamo la matrice per un cruciverba standard.
    List<List<int>> tickets = [];
    int cols = 6;
    int rows = (pool.length / cols).ceil();
    
    // Riempiamo la griglia
    List<List<int?>> grid = List.generate(rows, (_) => List.generate(cols, (_) => null));
    int k = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (k < pool.length) {
          grid[r][c] = pool[k];
          k++;
        }
      }
    }

    // 1. Orizzontali (Righe)
    for (int r = 0; r < rows; r++) {
      List<int> row = [];
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != null) row.add(grid[r][c]!);
      }
      if (row.length == 6) {
        row.sort();
        tickets.add(row);
      }
    }

    // 2. Verticali (Colonne)
    for (int c = 0; c < cols; c++) {
      List<int> col = [];
      for (int r = 0; r < rows; r++) {
        if (grid[r][c] != null) col.add(grid[r][c]!);
      }
      if (col.length == 6) {
        col.sort();
        tickets.add(col);
      }
    }
    
    return tickets;
  }
}
