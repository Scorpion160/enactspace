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
                style: const TextStyle(
                  color: AppTheme.secondaryText,
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
                style: const TextStyle(
                  color: AppTheme.secondaryText,
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            ...(subtitle == null
                ? const <Widget>[]
                : [
                    Text(
                      subtitle!,
                      style: const TextStyle(color: AppTheme.secondaryText),
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
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 48),
        backgroundColor: AppTheme.softBlack,
        foregroundColor: Colors.white,
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
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        foregroundColor: AppTheme.softBlack,
        side: const BorderSide(color: AppTheme.border),
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
    final colors = switch (tone) {
      AppStatusTone.success => (const Color(0xFFE3F3E8), AppTheme.success),
      AppStatusTone.warning => (const Color(0xFFFFF0D4), AppTheme.warning),
      AppStatusTone.error => (const Color(0xFFFCE5E5), AppTheme.error),
      AppStatusTone.info => (const Color(0xFFE1F1F7), AppTheme.information),
      AppStatusTone.neutral => (
        const Color(0xFFECECE8),
        AppTheme.secondaryText,
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
    final accent = switch (tone) {
      AppStatusTone.error => AppTheme.error,
      AppStatusTone.warning => AppTheme.warning,
      AppStatusTone.success => AppTheme.success,
      AppStatusTone.info => AppTheme.information,
      AppStatusTone.neutral => AppTheme.softBlack,
    };
    return AppDataCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, color: accent, size: 22),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (detail != null)
            Text(
              detail!,
              style: const TextStyle(
                color: AppTheme.secondaryText,
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
  Widget build(BuildContext context) => Material(
    color: AppTheme.surfaceElevated,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      side: const BorderSide(color: AppTheme.border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Padding(padding: padding, child: child),
    ),
  );
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 8,
              color: AppTheme.enactusYellow,
              backgroundColor: AppTheme.border,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              detail!,
              style: const TextStyle(
                color: AppTheme.secondaryText,
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
        Icon(icon, color: AppTheme.secondaryText, size: 28),
        const SizedBox(width: AppTheme.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                message,
                style: const TextStyle(color: AppTheme.secondaryText),
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
