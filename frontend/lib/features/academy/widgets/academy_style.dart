import 'package:flutter/material.dart';

const academyYellow = Color(0xFFFFC72C);
const academyInk = Color(0xFF101920);

/// The Academy palette is local: application and system preferences are intact.
class AcademyStyle extends StatelessWidget {
  final Widget child;
  final Brightness? brightness;
  const AcademyStyle({super.key, required this.child, this.brightness});

  @override
  Widget build(BuildContext context) {
    final inherited = Theme.of(context);
    final dark = (brightness ?? inherited.brightness) == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF008B98),
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: dark ? const Color(0xFF35CFDA) : const Color(0xFF00838F),
          onPrimary: dark ? academyInk : Colors.white,
          surface: dark ? const Color(0xFF17222D) : Colors.white,
          surfaceContainerLowest: dark
              ? const Color(0xFF0C1218)
              : const Color(0xFFF6F4EE),
          surfaceContainerLow: dark
              ? const Color(0xFF14202A)
              : const Color(0xFFFAF9F5),
          surfaceContainerHighest: dark
              ? const Color(0xFF273743)
              : const Color(0xFFEDEEEA),
          onSurface: dark ? const Color(0xFFF4F7FA) : academyInk,
          onSurfaceVariant: dark
              ? const Color(0xFFBAC7D5)
              : const Color(0xFF52606D),
          secondaryContainer: dark
              ? const Color(0xFF15333A)
              : const Color(0xFFE1F3F3),
          onSecondaryContainer: dark
              ? const Color(0xFFD5F5F4)
              : const Color(0xFF123C43),
          tertiaryContainer: dark
              ? const Color(0xFF3D321D)
              : const Color(0xFFFFF0CA),
          onTertiaryContainer: dark
              ? const Color(0xFFFFE5A8)
              : const Color(0xFF493510),
          outlineVariant: dark
              ? const Color(0xFF30434F)
              : const Color(0xFFE1E4E2),
        );
    final theme = inherited.copyWith(
      brightness: colors.brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surfaceContainerLowest,
      textTheme: inherited.textTheme.apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
      iconTheme: inherited.iconTheme.copyWith(color: colors.onSurface),
      primaryIconTheme: inherited.primaryIconTheme.copyWith(
        color: colors.onSurface,
      ),
      dividerColor: colors.outlineVariant,
      appBarTheme: inherited.appBarTheme.copyWith(
        backgroundColor: colors.surfaceContainerLowest,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: inherited.cardTheme.copyWith(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: academyYellow,
          foregroundColor: academyInk,
          disabledBackgroundColor: colors.surfaceContainerHighest,
          disabledForegroundColor: colors.onSurfaceVariant,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, height: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          minimumSize: const Size(48, 44),
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: ColoredBox(color: colors.surfaceContainerLowest, child: child),
    );
  }
}

class AcademyPill extends StatelessWidget {
  final String label;
  final bool warm;
  const AcademyPill(this.label, {super.key, this.warm = false});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warm ? colors.tertiaryContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: warm
              ? colors.onTertiaryContainer
              : colors.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AcademyProgressBar extends StatelessWidget {
  final double value;
  final String? label;
  const AcademyProgressBar({super.key, required this.value, this.label});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LinearProgressIndicator(
        value: value.isFinite ? value.clamp(0.0, 1.0) : 0,
        minHeight: 8,
        color: academyYellow,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      if (label != null) ...[
        const SizedBox(height: 8),
        Text(
          label!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}
