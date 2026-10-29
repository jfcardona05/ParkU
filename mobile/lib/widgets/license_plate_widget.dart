import 'package:flutter/material.dart';

class LicensePlateWidget extends StatelessWidget {
  final String plate;
  final double fontSize;

  const LicensePlateWidget({
    super.key,
    required this.plate,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFBC02D), // Amarillo placa Colombia
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plate.toUpperCase(),
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              letterSpacing: 2.0,
            ),
          ),
          const Text(
            'COLOMBIA',
            style: TextStyle(
              color: Color(0xFF333333),
              fontWeight: FontWeight.w800,
              fontSize: 7,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
