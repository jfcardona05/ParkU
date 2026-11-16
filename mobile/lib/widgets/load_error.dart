import 'package:flutter/material.dart';
import '../ui/park_widgets.dart';

class LoadError extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const LoadError({super.key, required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => ParkNotice(message, retry: retry);
}
