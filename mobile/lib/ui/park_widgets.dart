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
    this.padding = const EdgeInsets.all(22),
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: color == Colors.white
            ? const Color(0xFFE8EBE4)
            : Colors.transparent,
      ),
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
    this.breakpoint = 600,
    this.gap = 20,
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
                  fontSize: MediaQuery.sizeOf(context).width < 760 ? 28 : 34,
                ),
              ),
              const SizedBox(height: 8),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (size.maxWidth < 650) {
        return ParkCard(
          child: Column(
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParkGlyph(item.$1, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }
      return ParkColumns(
        children: [
          for (final item in items)
            ParkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParkGlyph(item.$1, size: 28),
                  const SizedBox(height: 12),
                  Text(item.$2, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
        ],
      );
    },
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

/// Illustrative vehicles, bundled locally; never a photograph of the user's actual vehicle.
class ParkCar extends StatelessWidget {
  final bool motorcycle;
  final double maxWidth;
  final bool crossover;
  const ParkCar({
    super.key,
    this.motorcycle = false,
    this.maxWidth = 350,
    this.crossover = false,
  });
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AspectRatio(
          aspectRatio: 1.95,
          child: Image.asset(
            motorcycle
                ? 'assets/vehicles/motorcycle-yellow.png'
                : crossover
                ? 'assets/vehicles/crossover-ivory.png'
                : 'assets/vehicles/compact-blue.png',
            fit: BoxFit.contain,
            cacheWidth: 1000,
          ),
        ),
      ),
    ),
  );
}

class ParkAvailabilitySoon extends StatelessWidget {
  final bool yellow;
  final bool showDefaultCapacity;
  const ParkAvailabilitySoon({
    super.key,
    this.yellow = false,
    this.showDefaultCapacity = false,
  });
  @override
  Widget build(BuildContext context) => ParkCard(
    color: yellow ? ParkColors.yellow : Colors.white,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_parking_outlined, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cupos de parqueadero',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (showDefaultCapacity)
          Text('0/1000', style: Theme.of(context).textTheme.headlineMedium)
        else
          const ParkBadge('Próximamente'),
        const SizedBox(height: 10),
        Text(
          showDefaultCapacity
              ? 'Cupos ocupados / capacidad de referencia'
              : 'La disponibilidad estará aquí cuando se habilite el control de ingresos.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
