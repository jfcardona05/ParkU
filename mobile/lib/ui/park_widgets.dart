import 'package:flutter/material.dart';
import 'park_theme.dart';

class ParkCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  const ParkCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class ParkColumns extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double breakpoint;
  const ParkColumns({
    super.key,
    required this.children,
    this.flex,
    this.breakpoint = 720,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 20),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(flex: flex?[i] ?? 1, child: children[i]),
          ],
        ],
      );
    },
  );
}

class ParkHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const ParkHeading(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class ParkBadge extends StatelessWidget {
  final String text;
  final bool success;
  const ParkBadge(this.text, {super.key, this.success = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: success ? ParkColors.greenLight : ParkColors.background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: success ? ParkColors.green : ParkColors.muted,
      ),
    ),
  );
}

class ParkIcon extends StatelessWidget {
  final IconData icon;
  const ParkIcon(this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: ParkColors.background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, size: 23, color: ParkColors.ink),
  );
}

class ParkFeatures extends StatelessWidget {
  final List<(IconData, String, String)> items;
  const ParkFeatures({super.key, required this.items});
  @override
  Widget build(BuildContext context) => ParkColumns(
    breakpoint: 650,
    children: [
      for (final item in items)
        ParkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.$1, size: 22),
              const SizedBox(height: 12),
              Text(item.$2, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
    ],
  );
}

class ParkNotice extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const ParkNotice(this.message, {super.key, this.retry});
  @override
  Widget build(BuildContext context) => ParkCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline),
        const SizedBox(height: 12),
        Text(message),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Reintentar')),
      ],
    ),
  );
}

/// Local vector illustration: no remote image requests or personal data.
class ParkCar extends StatelessWidget {
  final bool motorcycle;
  const ParkCar({super.key, this.motorcycle = false});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 2.35,
      child: CustomPaint(painter: _CarPainter(motorcycle)),
    ),
  );
}

class _CarPainter extends CustomPainter {
  final bool motorcycle;
  const _CarPainter(this.motorcycle);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 150);
    final paint = Paint()..isAntiAlias = true;
    void rect(Rect r, Color color, double radius) {
      paint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)),
        paint,
      );
    }

    if (motorcycle) {
      rect(const Rect.fromLTWH(58, 64, 240, 26), ParkColors.ink, 13);
      rect(const Rect.fromLTWH(119, 54, 90, 44), const Color(0xFFC7C8CA), 18);
      rect(const Rect.fromLTWH(179, 61, 65, 30), ParkColors.yellow, 15);
      paint
        ..color = ParkColors.ink
        ..strokeWidth = 8;
      canvas.drawLine(const Offset(236, 39), const Offset(236, 112), paint);
    } else {
      rect(const Rect.fromLTWH(25, 29, 308, 98), const Color(0x1A191927), 42);
      for (final x in [76.0, 257.0]) {
        rect(Rect.fromLTWH(x, 18, 34, 19), ParkColors.ink, 6);
        rect(Rect.fromLTWH(x, 115, 34, 19), ParkColors.ink, 6);
      }
      rect(const Rect.fromLTWH(22, 24, 315, 104), const Color(0xFFB7B8BA), 42);
      rect(const Rect.fromLTWH(26, 28, 307, 96), const Color(0xFFF1F1F1), 39);
      rect(const Rect.fromLTWH(60, 31, 221, 90), const Color(0xFF57575F), 30);
      final glass = Path()
        ..moveTo(232, 34)
        ..lineTo(261, 42)
        ..quadraticBezierTo(282, 75, 259, 110)
        ..lineTo(232, 117)
        ..quadraticBezierTo(253, 75, 232, 34);
      paint.color = const Color(0xFF24242E);
      canvas.drawPath(glass, paint);
      rect(const Rect.fromLTWH(97, 40, 130, 72), const Color(0xFFE7E8E9), 12);
      final back = Path()
        ..moveTo(77, 37)
        ..lineTo(97, 41)
        ..lineTo(97, 111)
        ..lineTo(77, 116)
        ..quadraticBezierTo(55, 75, 77, 37);
      paint.color = const Color(0xFF292932);
      canvas.drawPath(back, paint);
      rect(const Rect.fromLTWH(282, 42, 43, 67), const Color(0xFFE8E8E9), 18);
      rect(const Rect.fromLTWH(327, 55, 7, 39), ParkColors.ink, 3);
      rect(const Rect.fromLTWH(28, 43, 7, 23), const Color(0xFFCC2B40), 4);
      rect(const Rect.fromLTWH(28, 88, 7, 23), const Color(0xFFCC2B40), 4);
      paint
        ..color = const Color(0xFF95959C)
        ..strokeWidth = 1;
      canvas.drawLine(const Offset(109, 34), const Offset(229, 34), paint);
      canvas.drawLine(const Offset(109, 117), const Offset(229, 117), paint);
      rect(const Rect.fromLTWH(224, 17, 14, 13), const Color(0xFFD0D0D3), 3);
      rect(const Rect.fromLTWH(224, 122, 14, 13), const Color(0xFFD0D0D3), 3);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarPainter oldDelegate) =>
      motorcycle != oldDelegate.motorcycle;
}
