import 'package:flutter/material.dart';

/// A visual seat layout for shared vans — booked seats are filled, available
/// ones are open. For minivan/hiace this reads like a real van seat chart.
class SeatMap extends StatelessWidget {
  const SeatMap({
    super.key,
    required this.seatsTotal,
    required this.seatsAvailable,
    this.perRow = 4,
    this.compact = false,
  });

  final int seatsTotal;
  final int seatsAvailable;
  final int perRow;
  final bool compact;

  int get reserved => (seatsTotal - seatsAvailable).clamp(0, seatsTotal);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final booked = theme.colorScheme.primary;
    final free = theme.colorScheme.outlineVariant;
    // Seats fill from the front as they're booked (count-based, not assigned).
    final seats = <Widget>[
      for (int i = 0; i < seatsTotal; i++)
        _Seat(taken: i < reserved, takenColor: booked, freeColor: free, size: compact ? 20 : 26),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.airline_seat_recline_normal_rounded,
                size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 6),
            Text('$seatsAvailable of $seatsTotal seats available',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline, fontWeight: FontWeight.w600)),
            const Spacer(),
            _LegendDot(color: booked, label: 'Booked'),
            const SizedBox(width: 8),
            _LegendDot(color: free, label: 'Free', outline: true),
          ],
        ),
        const SizedBox(height: 8),
        // Driver row.
        Row(
          children: [
            Icon(Icons.airline_seat_recline_extra_rounded,
                size: compact ? 20 : 26, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('Driver',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: seats),
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.taken,
    required this.takenColor,
    required this.freeColor,
    required this.size,
  });
  final bool taken;
  final Color takenColor;
  final Color freeColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: taken ? takenColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: taken ? takenColor : freeColor, width: 1.5),
      ),
      child: Icon(Icons.event_seat_rounded,
          size: size * 0.6, color: taken ? Colors.white : freeColor),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, this.outline = false});
  final Color color;
  final String label;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: outline ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}
