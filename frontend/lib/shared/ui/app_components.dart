import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppResponsiveContainer extends StatelessWidget {
  const AppResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1480,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 1440
        ? 36.0
        : width >= 1200
        ? 32.0
        : width >= 700
        ? 24.0
        : 16.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ?? EdgeInsets.fromLTRB(horizontal, 24, horizontal, 32),
          child: child,
        ),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (eyebrow != null)
              Text(
                eyebrow!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: compact ? 26 : 32,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.space8),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );
        return Wrap(
          spacing: AppTheme.space16,
          runSpacing: AppTheme.space16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...(leading == null ? const <Widget>[] : [leading!]),
            SizedBox(width: compact ? constraints.maxWidth : 460, child: text),
            ...actions,
          ],
        );
      },
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            ...(subtitle == null
                ? const <Widget>[]
                : [
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]),
          ],
        ),
      ),
      ..._present(action),
    ],
  );
}

List<T> _present<T>(T? value) => value == null ? const [] : [value];

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.expand = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 48),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.expand = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        foregroundColor: colors.onSurface,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badge,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final int? badge;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Badge(
      isLabelVisible: (badge ?? 0) > 0,
      label: Text('${badge ?? 0}'),
      child: Icon(icon),
    ),
  );
}

enum AppStatusTone { neutral, success, warning, error, info }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
  });
  final String label;
  final AppStatusTone tone;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    (Color, Color) accentColors(Color accent) => (
      accent.withValues(alpha: dark ? 0.24 : 0.12),
      dark ? Color.lerp(accent, Colors.white, 0.48)! : accent,
    );
    final colors = switch (tone) {
      AppStatusTone.success => accentColors(AppTheme.success),
      AppStatusTone.warning => accentColors(AppTheme.warning),
      AppStatusTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      AppStatusTone.info => accentColors(AppTheme.information),
      AppStatusTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.$2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppMetric extends StatelessWidget {
  const AppMetric({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.icon,
    this.tone = AppStatusTone.neutral,
    this.onTap,
  });
  final String label;
  final String value;
  final String? detail;
  final IconData? icon;
  final AppStatusTone tone;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final accent = switch (tone) {
      AppStatusTone.error => AppTheme.error,
      AppStatusTone.warning => AppTheme.warning,
      AppStatusTone.success => AppTheme.success,
      AppStatusTone.info => AppTheme.information,
      AppStatusTone.neutral => Theme.of(context).colorScheme.onSurface,
    };
    return AppDataCard(
      onTap: onTap,
      child: Column(
        mainAxisSize: largeText ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, color: accent, size: 22),
          if (largeText) const SizedBox(height: 12) else const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
          if (detail != null)
            Text(
              detail!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class AppDataCard extends StatelessWidget {
  const AppDataCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.space20),
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppIdentityCell extends StatelessWidget {
  const AppIdentityCell({
    super.key,
    required this.name,
    this.subtitle,
    this.imageUrl,
    this.trailing,
  });

  final String name;
  final String? subtitle;
  final String? imageUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Row(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.28),
          foregroundColor: AppTheme.softBlack,
          backgroundImage: imageUrl == null || imageUrl!.isEmpty
              ? null
              : NetworkImage(imageUrl!),
          child: imageUrl == null || imageUrl!.isEmpty
              ? Text(
                  initials.isEmpty ? '?' : initials,
                  style: TextStyle(fontWeight: FontWeight.w800),
                )
              : null,
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        ..._present(trailing),
      ],
    );
  }
}

class AppProgressSummary extends StatelessWidget {
  const AppProgressSummary({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.detail,
  });

  final String label;
  final String value;
  final double progress;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final normalized = progress.clamp(0.0, 1.0);
    return AppDataCard(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(value, style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 8,
              color: AppTheme.enactusYellow,
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              detail!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => AppDataCard(
    child: Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 28,
        ),
        const SizedBox(width: AppTheme.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
              Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...(action == null ? const <Widget>[] : [action!]),
      ],
    ),
  );
}

class AppFilterBar extends StatelessWidget {
  const AppFilterBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AppDataCard(
    padding: const EdgeInsets.all(AppTheme.space12),
    child: child,
  );
}

class AppMobileBottomNavigation extends StatelessWidget {
  const AppMobileBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });
  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 72,
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: destinations,
  );
}

class AppDesktopNavigationRail extends StatelessWidget {
  const AppDesktopNavigationRail({
    super.key,
    required this.header,
    required this.navigation,
    required this.footer,
  });
  final Widget header;
  final Widget navigation;
  final Widget footer;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 232,
    child: ColoredBox(
      color: AppTheme.softBlack,
      child: SafeArea(
        child: Column(
          children: [
            header,
            const Divider(color: Colors.white12),
            Expanded(child: navigation),
            const Divider(color: Colors.white12),
            footer,
          ],
        ),
      ),
    ),
  );
}
