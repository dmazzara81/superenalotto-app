import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  // TODO: Inserisci qui la tua chiave pubblica di RevenueCat
  static const String _revenueCatApiKeyAndroid = 'goog_INSERISCI_CHIAVE_QUI';
  static const String _revenueCatApiKeyIOS = 'appl_INSERISCI_CHIAVE_QUI';

  // Singleton
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  /// Inizializza l'SDK di RevenueCat. Da chiamare in main.dart
  Future<void> init() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      
      late PurchasesConfiguration configuration;
      
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_revenueCatApiKeyAndroid);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_revenueCatApiKeyIOS);
      } else {
        return; // RevenueCat non supportato su questa piattaforma
      }
      
      await Purchases.configure(configuration);
      debugPrint('[RevenueCat] Inizializzato con successo');
    } catch (e) {
      debugPrint('[RevenueCat] Errore inizializzazione: $e');
    }
  }

  /// Verifica se l'utente ha un abbonamento PRO attivo
  Future<bool> isProUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // Assumiamo che l'entitlement su RevenueCat si chiami "pro_access"
      return customerInfo.entitlements.all['pro_access']?.isActive ?? false;
    } catch (e) {
      debugPrint('[RevenueCat] Errore verifica PRO: $e');
      return false;
    }
  }

  /// Recupera le offerte (Packages) configurate su RevenueCat
  Future<List<Package>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
      return [];
    } catch (e) {
      debugPrint('[RevenueCat] Errore recupero offerte: $e');
      return [];
    }
  }

  /// Esegue l'acquisto di un pacchetto
  Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.all['pro_access']?.isActive ?? false;
    } catch (e) {
      debugPrint('[RevenueCat] Errore durante acquisto: $e');
      return false;
    }
  }

  /// Ripristina gli acquisti precedenti (es. se l'utente cambia telefono)
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all['pro_access']?.isActive ?? false;
    } catch (e) {
      debugPrint('[RevenueCat] Errore ripristino acquisti: $e');
      return false;
    }
  }
}
