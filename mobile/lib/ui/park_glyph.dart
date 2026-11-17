import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'park_theme.dart';

/// Original exported SVGs retain their intrinsic root dimensions and colors.
class ParkGlyph extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  const ParkGlyph(this.icon, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final muted = color == ParkColors.muted;
    String? asset;
    double dimension = size;
    if (icon == Icons.home_outlined) {
      asset = size <= 21 ? (muted ? 'ae0db' : '24a7c') : 'c5b91';
      dimension = size <= 21 ? 21 : 22;
    } else if (icon == Icons.directions_car_outlined ||
        icon == Icons.storefront_outlined) {
      asset = size == 28
          ? 'cab47'
          : size == 25
          ? 'c0f51'
          : size == 24
          ? '8f3a7'
          : size <= 21
          ? (muted ? '7b337' : 'e4593')
          : '5b1f0';
      dimension = size == 28 ? 28 : size == 25 ? 25 : size == 24 ? 24 : size <= 21 ? 21 : 22;
    } else if (icon == Icons.account_balance_wallet_outlined) {
      asset = size <= 20
          ? 'd9cd4'
          : size <= 21
          ? (muted ? '7f6c1' : 'b4eeb')
          : '843c7';
      dimension = size <= 20 ? 20 : size <= 21 ? 21 : 22;
    } else if (icon == Icons.local_parking_outlined ||
        icon == Icons.qr_code_2_outlined ||
        icon == Icons.history_outlined) {
      asset = size == 28
          ? 'd210e'
          : size == 24
          ? '40395'
          : size <= 21
          ? (muted ? 'd6ae4' : '8f4ff')
          : 'dfbad';
      dimension = size == 28 ? 28 : size == 24 ? 24 : size <= 21 ? 21 : 22;
    } else if (icon == Icons.sensor_door_outlined) {
      asset = size <= 20 ? '5c73a' : size == 24 ? '8eb16' : 'f72b1';
      dimension = size <= 20 ? 20 : size == 24 ? 24 : 22;
    } else if (icon == Icons.qr_code_scanner) {
      asset = size >= 100 ? '2969a' : 'ea9ff';
      dimension = size >= 100 ? 140 : 68;
    }
    if (asset == null) return Icon(icon, size: size, color: color);
    return ExcludeSemantics(
      child: SizedBox(
        width: dimension,
        height: dimension,
        child: SvgPicture.asset('assets/figma/$asset.svg'),
      ),
    );
  }
}
