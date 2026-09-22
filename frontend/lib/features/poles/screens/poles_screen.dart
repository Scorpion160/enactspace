import 'package:flutter/material.dart';

import '../services/poles_portfolio_gateway.dart';
import 'poles_portfolio_screen.dart';

/// Point d’entrée historique conservé pour les imports existants.
class PolesScreen extends StatelessWidget {
  final PolesPortfolioGateway? gateway;

  const PolesScreen({super.key, this.gateway});

  @override
  Widget build(BuildContext context) => PolesPortfolioScreen(gateway: gateway);
}
