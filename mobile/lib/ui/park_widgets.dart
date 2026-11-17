import 'package:flutter/material.dart';
import 'park_theme.dart';
import 'park_glyph.dart';

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
  final double gap;
  const ParkColumns({
    super.key,
    required this.children,
    this.flex,
    this.breakpoint = 720,
    this.gap = 24,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
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
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: MediaQuery.sizeOf(context).width < 760 ? 28 : 36,
                ),
              ),
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
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5EB),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Center(child: ParkGlyph(icon, size: 24)),
  );
}

class ParkFeatures extends StatelessWidget {
  final List<(IconData, String, String)> items;
  const ParkFeatures({super.key, required this.items});
  @override
  Widget build(BuildContext context) => ParkColumns(
    breakpoint: 650,
    children: [
      for (final (index, item) in items.indexed)
        ParkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParkGlyph(
                index == 0
                    ? Icons.directions_car_outlined
                    : Icons.local_parking_outlined,
                size: 28,
              ),
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

/// Original Figma car, bundled locally and contained without stretching.
class ParkCar extends StatelessWidget {
  final bool motorcycle;
  const ParkCar({super.key, this.motorcycle = false});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 490 / 213.15,
      child: motorcycle
          ? const Center(child: Icon(Icons.two_wheeler_outlined, size: 88))
          : Image.asset('assets/figma/43925.png', fit: BoxFit.contain),
    ),
  );
}
