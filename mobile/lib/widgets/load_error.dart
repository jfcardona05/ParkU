import 'package:flutter/material.dart';

class LoadError extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const LoadError({super.key, required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: retry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
