import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:superenalotto/core/services/revenuecat_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = true;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    final packages = await RevenueCatService().getOfferings();
    if (mounted) {
      setState(() {
        _packages = packages;
        _isLoading = false;
      });
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isLoading = true);
    final success = await RevenueCatService().purchasePackage(package);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acquisto completato! Sei ora un utente PRO 🚀'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Ritorna true se acquistato
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acquisto annullato o fallito.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final success = await RevenueCatService().restorePurchases();
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acquisti ripristinati con successo! Bentornato PRO.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessun acquisto precedente trovato.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark/premium theme
      body: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.15),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        const Icon(Icons.star, color: Colors.amber, size: 80),
                        const SizedBox(height: 16),
                        const Text(
                          'Sblocca il\nPotere Quantistico',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Passa a PRO e accedi a tutti i sistemi avanzati e alle previsioni AI illimitate.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 40),
                        
                        // Benefici
                        _buildFeatureRow(Icons.psychology, 'Intelligenza Artificiale', 'Genera sestine con modelli LLM predittivi'),
                        _buildFeatureRow(Icons.calculate, 'Sistemi Cruciverba', 'Gioca matrici numeriche complesse (es. 6x6)'),
                        _buildFeatureRow(Icons.lock, 'Basi e Varianti', 'Fissa i tuoi numeri preferiti e fai girare gli altri'),
                        _buildFeatureRow(Icons.analytics, 'Statistiche Avanzate', 'Nessun limite alla visualizzazione di dati e frequenze'),
                        
                        const SizedBox(height: 40),
                        
                        if (_isLoading)
                          const CircularProgressIndicator(color: Colors.amber)
                        else if (_packages.isEmpty)
                          const Text('Nessuna offerta disponibile al momento.', style: TextStyle(color: Colors.white54))
                        else
                          Column(
                            children: _packages.map((pkg) => _buildPackageCard(pkg)).toList(),
                          ),
                          
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: _restorePurchases,
                          child: const Text('Hai già acquistato? Ripristina acquisti', style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPackageCard(Package package) {
    // Es. package.storeProduct.priceString -> "€4.99"
    final isAnnual = package.packageType == PackageType.annual;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        _purchasePackage(package);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isAnnual ? Colors.amber.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isAnnual ? Colors.amber : Colors.white12, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.storeProduct.title.split('(').first.trim(), // Rimuove "(App Name)"
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isAnnual)
                  Container(
                    margin: const EdgeInsets.top(4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                    child: const Text('RISPARMI IL 50%', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            Text(
              package.storeProduct.priceString,
              style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
