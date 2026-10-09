import 'package:flutter/material.dart';

import '../../data/models/flight.dart';
import '../formatters.dart';
import 'status_badge.dart';

/// Carte presentant un vol dans une liste.
class FlightCard extends StatelessWidget {
  const FlightCard({super.key, required this.flight, this.onTap});

  final Flight flight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = flight.originDetail?.code ?? '';
    final destination = flight.destinationDetail?.code ?? '';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$origin → $destination',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusBadge(status: flight.status, label: flight.statusLabel),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (flight.flightCode.isNotEmpty) ...[
                    Icon(Icons.confirmation_number_outlined,
                        size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(flight.flightCode,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.event_outlined,
                      size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(Formatters.formatDate(flight.flightDate),
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TimeChip(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Enreg.',
                    value: Formatters.formatTime(flight.registrationTime),
                  ),
                  const SizedBox(width: 8),
                  _TimeChip(
                    icon: Icons.flight_takeoff,
                    label: 'Départ',
                    value: Formatters.formatTime(flight.departureTime),
                  ),
                  const SizedBox(width: 8),
                  _TimeChip(
                    icon: Icons.flight_land,
                    label: 'Arrivée',
                    value: Formatters.formatTime(flight.arrivalTime),
                  ),
                ],
              ),
              if (flight.observation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 15, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        flight.observation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ],
              if (flight.isExceptional) ...[
                const SizedBox(height: 8),
                const _ExceptionalTag(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExceptionalTag extends StatelessWidget {
  const _ExceptionalTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Vol exceptionnel',
        style: TextStyle(
          fontSize: 11,
          color: Colors.deepPurple,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
