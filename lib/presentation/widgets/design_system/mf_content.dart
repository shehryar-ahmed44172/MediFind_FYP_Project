import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'mf_buttons.dart';
import 'mf_tokens.dart';

/// Section heading with optional trailing action ("See all").
class MfSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const MfSectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: MfSpace.xs),
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: text.titleMedium)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Icon + always-visible text label.
///
/// `vertical` layout for quick-action grids, horizontal for list rows (with
/// chevron). Minimum height 48dp (96dp for grid tiles).
class MfIconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final MfTone tone;
  final bool vertical;
  final Widget? trailing;
  final bool showChevron;
  final String? badge;

  const MfIconTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.tone = MfTone.primary,
    this.vertical = false,
    this.trailing,
    this.showChevron = true,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, tone);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final iconBox = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: t.container, borderRadius: MfRadius.smAll),
      child: Icon(icon, color: t.foreground, size: 22),
    );

    final badgeWidget = badge == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: cs.error, borderRadius: MfRadius.smAll),
            child: Text(badge!, style: text.labelSmall?.copyWith(color: cs.onError)),
          );

    if (vertical) {
      return Semantics(
        button: onTap != null,
        label: subtitle == null ? label : '$label. $subtitle',
        excludeSemantics: true,
        child: Material(
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: MfRadius.mdAll,
            side: BorderSide(color: cs.outlineVariant, width: MfColors.isHighContrast(context) ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Padding(
                padding: const EdgeInsets.all(MfSpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [iconBox, const Spacer(), if (badgeWidget != null) badgeWidget]),
                    const SizedBox(height: MfSpace.sm),
                    Text(label, style: text.titleSmall),
                    if (subtitle != null)
                      Text(subtitle!, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: onTap != null,
      label: subtitle == null ? label : '$label. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.xs),
            child: Row(
              children: [
                iconBox,
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: text.titleSmall?.copyWith(color: tone == MfTone.danger ? t.foreground : null)),
                      if (subtitle != null)
                        Text(subtitle!, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (badgeWidget != null) ...[badgeWidget, const SizedBox(width: MfSpace.xs)],
                if (trailing != null) trailing!,
                if (trailing == null && showChevron && onTap != null)
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty list / no-data state.
class MfEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool compact;

  const MfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? MfSpace.md : MfSpace.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 48 : 64,
                height: compact ? 48 : 64,
                decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: MfRadius.lgAll),
                child: Icon(icon, size: compact ? 24 : 32, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: MfSpace.md),
              Text(title, textAlign: TextAlign.center, style: text.titleMedium),
              if (message != null) ...[
                const SizedBox(height: MfSpace.xs),
                Text(message!, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: MfSpace.lg),
                MfPrimaryButton(label: actionLabel!, icon: actionIcon, onPressed: onAction, expanded: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with retry.
class MfErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  const MfErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? MfSpace.md : MfSpace.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: compact ? 32 : 40, color: cs.error),
              const SizedBox(height: MfSpace.sm),
              Text(title, textAlign: TextAlign.center, style: text.titleMedium),
              if (message != null) ...[
                const SizedBox(height: MfSpace.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: MfSpace.md),
                MfSecondaryButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry, expanded: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered loading indicator with optional label.
class MfLoading extends StatelessWidget {
  final String? label;
  const MfLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: label ?? 'Loading',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            if (label != null) ...[
              const SizedBox(height: MfSpace.sm),
              Text(label!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder block. Static when reduced motion is requested.
class MfSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const MfSkeleton({super.key, this.width, this.height = 16, this.radius = MfRadius.sm});

  /// A list of card-shaped skeletons.
  static Widget list({int count = 3, double itemHeight = 72}) => Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: MfSpace.sm),
              child: MfSkeleton(height: itemHeight, radius: MfRadius.md),
            ),
        ],
      );

  @override
  State<MfSkeleton> createState() => _MfSkeletonState();
}

class _MfSkeletonState extends State<MfSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MfMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(cs.surfaceContainer, cs.surfaceContainerHighest, _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Resolves stored profile image paths against the current server root.
String? mfResolveImageUrl(String? stored) {
  if (stored == null || stored.isEmpty) return null;
  String path;
  try {
    final uri = Uri.parse(stored);
    if (uri.hasScheme) {
      // Server uploads are re-rooted on the CURRENT server (the stored host may
      // be an old ngrok/LAN address). Other absolute URLs are used as-is.
      if (!uri.path.startsWith('/uploads')) return stored;
      path = uri.path;
    } else {
      path = stored;
    }
  } catch (_) {
    path = stored;
  }
  final root = AppConstants.socketUrl.endsWith('/')
      ? AppConstants.socketUrl.substring(0, AppConstants.socketUrl.length - 1)
      : AppConstants.socketUrl;
  return '$root${path.startsWith('/') ? path : '/$path'}';
}

/// Circular avatar with network image and initials fallback.
class MfAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final bool resolve;

  const MfAvatar({super.key, this.imageUrl, this.name, this.size = 44, this.resolve = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = resolve ? mfResolveImageUrl(imageUrl) : imageUrl;
    final initials = _initials(name);
    final fallback = Container(
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: initials.isEmpty
          ? Icon(Icons.person_outline_rounded, size: size * 0.5, color: cs.onPrimaryContainer)
          : Text(
              initials,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontSize: size * 0.36,
                  ),
              textScaler: TextScaler.noScaling,
            ),
    );
    return Semantics(
      image: true,
      label: name == null ? 'Profile photo' : 'Photo of $name',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: ClipOval(
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  headers: AppConstants.baseUrl.contains('ngrok')
                      ? const {'ngrok-skip-browser-warning': 'true'}
                      : null,
                  errorBuilder: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Role dashboard quick-action grid (SRS FR8.3): two columns of vertical
/// [MfIconTile]s with equal row heights.
class MfQuickActionGrid extends StatelessWidget {
  final List<Widget> children;
  const MfQuickActionGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < children.length; row += 2) ...[
          if (row > 0) const SizedBox(height: MfSpace.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[row]),
                const SizedBox(width: MfSpace.sm),
                Expanded(child: row + 1 < children.length ? children[row + 1] : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
