import 'package:flutter/material.dart';

/// The application and the association remain legible on photographs and white.
class EnactBrandLockup extends StatelessWidget {
  final bool translucent;
  const EnactBrandLockup({super.key, this.translucent = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: translucent ? const Color(0xBFFFFFFF) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: [
        Image.asset(
          'assets/brand/logo/enactspace_logo_full_transparent.png',
          width: 160,
          height: 100,
          fit: BoxFit.contain,
          semanticLabel: 'EnactSpace',
        ),
        Image.asset(
          'assets/img/logo_enactus_esp.png',
          width: 120,
          height: 100,
          fit: BoxFit.contain,
          semanticLabel: 'Enactus ESP',
        ),
      ],
    ),
  );
}

