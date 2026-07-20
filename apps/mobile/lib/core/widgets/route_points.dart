import 'package:flutter/material.dart';

/// The origin→destination visual used across ride and booking cards:
/// a green dot, a dotted connector, and a destination pin.
class RoutePoints extends StatelessWidget {
  const RoutePoints({super.key, required this.origin, required this.destination});

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
              ),
            ),
            Expanded(
              child: CustomPaint(
                size: const Size(2, double.infinity),
                painter: _DottedLinePainter(theme.colorScheme.outlineVariant),
              ),
            ),
            Icon(Icons.location_on, size: 16, color: theme.colorScheme.error),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(origin, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Text(destination, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  const _DottedLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 3.0;
    const gap = 4.0;
    var y = 2.0;
    final x = size.width / 2;
    while (y < size.height - 2) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + dash).clamp(0, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) => oldDelegate.color != color;
}
