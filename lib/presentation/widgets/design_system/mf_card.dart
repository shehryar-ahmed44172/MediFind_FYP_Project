import 'package:flutter/material.dart';
import 'mf_tokens.dart';

/// Flat surface card with a 1px border. Tappable when [onTap] is set.
///
/// [tone] tints the background and border (e.g. `MfTone.danger` for an
/// active-SOS card). [solid] fills the card with the tone's solid color.
class MfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final MfTone? tone;
  final bool solid;
  final Color? color;
  final String? semanticLabel;
  final double radius;

  const MfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MfSpace.md),
    this.onTap,
    this.tone,
    this.solid = false,
    this.color,
    this.semanticLabel,
    this.radius = MfRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hc = MfColors.isHighContrast(context);
    Color bg = color ?? cs.surface;
    Color border = cs.outlineVariant;
    if (tone != null) {
      final t = MfColors.tone(context, tone!);
      bg = solid ? t.solid : Color.alphaBlend(t.container, cs.surface);
      border = solid ? t.solid : t.border;
    }
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: border, width: hc ? 2 : 1),
    );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, customBorder: shape, child: content);
    }

    final card = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (semanticLabel == null && onTap == null) return card;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: card,
    );
  }
}

/// Groups rows (e.g. [MfIconTile] list rows) in one card separated by dividers.
class MfListGroup extends StatelessWidget {
  final List<Widget> children;
  const MfListGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md));
      }
    }
    return MfCard(
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

/// Label / value pair (account info, credentials, medical data).
class MfKeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final Widget? trailing;

  const MfKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: MfSpace.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: text.titleSmall?.copyWith(color: valueColor)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Compact metric: big value + label (ratings, counts).
class MfStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final MfTone tone;

  const MfStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.tone = MfTone.primary,
  });

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, tone);
    final text = Theme.of(context).textTheme;
    return MfCard(
      padding: const EdgeInsets.all(MfSpace.sm),
      semanticLabel: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: t.foreground),
            const SizedBox(height: MfSpace.xs),
          ],
          Text(value, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
