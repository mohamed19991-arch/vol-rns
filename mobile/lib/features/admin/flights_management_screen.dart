import 'package:flutter/material.dart';

import '../agent/flight_management_screen.dart';

/// Gestion des vols côté administrateur : mêmes fonctionnalités que l'agent,
/// avec en plus la suppression (désactivation logique côté backend).
class FlightsManagementScreen extends StatelessWidget {
  const FlightsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FlightManagementScreen(allowDelete: true);
  }
}
