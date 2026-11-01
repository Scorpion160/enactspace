import 'package:flutter/material.dart';

const recruitmentYellow = Color(0xFFFFC72C);
const recruitmentInk = Color(0xFF101920);

/// Shared recruitment palette, aligned with Academy without changing the app theme.
class RecruitmentStyle extends StatelessWidget {
  final Widget child;
  final Brightness? brightness;
  final bool paintBackground;
  const RecruitmentStyle({
    super.key,
    required this.child,
    this.brightness,
    this.paintBackground = true,
  });

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
          onPrimary: dark ? recruitmentInk : Colors.white,
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
          onSurface: dark ? const Color(0xFFF4F7FA) : recruitmentInk,
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
      dialogTheme: inherited.dialogTheme.copyWith(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: inherited.textTheme.titleLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: inherited.textTheme.bodyMedium?.copyWith(
          color: colors.onSurface,
        ),
      ),
      inputDecorationTheme: inherited.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      chipTheme: inherited.chipTheme.copyWith(
        backgroundColor: colors.surface,
        selectedColor: recruitmentYellow,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? recruitmentInk
                : colors.onSurface,
          ),
        ),
        secondaryLabelStyle: const TextStyle(color: recruitmentInk),
        checkmarkColor: recruitmentInk,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      appBarTheme: inherited.appBarTheme.copyWith(
        backgroundColor: colors.surfaceContainerLowest,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: inherited.appBarTheme.titleTextStyle?.copyWith(
          color: colors.onSurface,
        ),
        toolbarTextStyle: inherited.appBarTheme.toolbarTextStyle?.copyWith(
          color: colors.onSurface,
        ),
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
          backgroundColor: recruitmentYellow,
          foregroundColor: recruitmentInk,
          disabledBackgroundColor: colors.surfaceContainerHighest,
          disabledForegroundColor: colors.onSurfaceVariant,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: inherited.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
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
      child: paintBackground
          ? ColoredBox(color: colors.surfaceContainerLowest, child: child)
          : child,
    );
  }
}

/// Dialog routes live above the local Theme, so capture the same palette here.
Future<T?> showRecruitmentDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (context) => RecruitmentStyle(
    paintBackground: false,
    child: Builder(builder: builder),
  ),
);
