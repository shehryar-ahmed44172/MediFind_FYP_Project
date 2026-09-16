import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import 'mf_content.dart';
import 'mf_tokens.dart';

/// Where "back" goes when there is nothing to pop (deep link / go()).
String mfHomeRouteForRole(String? role) {
  switch (role) {
    case 'CAREGIVER':
      return '/caregiver';
    case 'RESPONDER':
      return '/responder';
    default:
      return '/home';
  }
}

/// THE app header: flat surface, 1px bottom border, left-aligned title,
/// labeled back button, right-side actions (always with tooltips).
class MfHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// null = automatic (shown when the route can pop).
  final bool? showBack;
  final VoidCallback? onBack;

  /// Route used by back when nothing can be popped.
  final String? fallbackRoute;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  /// Shows the MediFind logo mark before the title (dashboard home tabs).
  final bool showBrand;

  const MfHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack,
    this.onBack,
    this.fallbackRoute,
    this.leading,
    this.bottom,
    this.showBrand = false,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(MfSize.headerHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop();
    final back = showBack ?? (canPop || fallbackRoute != null || onBack != null);

    Widget? lead = leading;
    if (lead == null && back) {
      lead = IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: onBack ??
            () {
              final router = GoRouter.maybeOf(context);
              if (router != null && router.canPop()) {
                router.pop();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                final role = ref.read(currentUserProvider).valueOrNull?.role;
                context.go(fallbackRoute ?? mfHomeRouteForRole(role));
              }
            },
      );
    }

    return AppBar(
      toolbarHeight: MfSize.headerHeight,
      automaticallyImplyLeading: false,
      leading: lead,
      titleSpacing: lead == null ? MfSpace.md : 0,
      backgroundColor: cs.surface,
      title: Semantics(
        header: true,
        child: Row(
          children: [
            if (showBrand) ...[
              Image.asset(
                'assets/logos/medifind_mark.png',
                width: 32,
                height: 32,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: MfSpace.xs),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [...actions, const SizedBox(width: MfSpace.xxs)],
      bottom: bottom,
    );
  }
}

/// Standard page: [MfHeader] + body + optional sticky bottom action area.
class MfScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool? showBack;
  final VoidCallback? onBack;
  final String? fallbackRoute;
  final Widget body;

  /// Sticky bottom area (primary actions). Padded and bordered automatically.
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final PreferredSizeWidget? headerBottom;
  final bool resizeToAvoidBottomInset;

  const MfScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.showBack,
    this.onBack,
    this.fallbackRoute,
    this.bottomBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.headerBottom,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: MfHeader(
        title: title,
        subtitle: subtitle,
        actions: actions,
        showBack: showBack,
        onBack: onBack,
        fallbackRoute: fallbackRoute,
        bottom: headerBottom,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar == null ? null : MfBottomActionBar(child: bottomBar!),
    );
  }
}

/// Sticky bottom container for primary actions.
class MfBottomActionBar extends StatelessWidget {
  final Widget child;
  const MfBottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.sm, MfSpace.md, MfSpace.sm),
          child: child,
        ),
      ),
    );
  }
}

/// Floating header for full-screen map screens: back button + title card +
/// actions, all on bordered surface chips so they read on top of the map.
class MfFloatingHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;
  final String? fallbackRoute;
  final Widget? titleTrailing;

  const MfFloatingHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.showBack = true,
    this.fallbackRoute,
    this.titleTrailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final border = BorderSide(color: cs.outlineVariant, width: MfColors.isHighContrast(context) ? 2 : 1);

    Widget surface(Widget child, {EdgeInsetsGeometry? padding}) => Material(
          color: cs.surface,
          elevation: 1,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: MfRadius.mdAll, side: border),
          child: padding == null ? child : Padding(padding: padding, child: child),
        );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(MfSpace.sm, MfSpace.xs, MfSpace.sm, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBack) ...[
              surface(
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: onBack ??
                      () {
                        final router = GoRouter.maybeOf(context);
                        if (router != null && router.canPop()) {
                          router.pop();
                        } else {
                          final role = ref.read(currentUserProvider).valueOrNull?.role;
                          context.go(fallbackRoute ?? mfHomeRouteForRole(role));
                        }
                      },
                ),
              ),
              const SizedBox(width: MfSpace.xs),
            ],
            Expanded(
              child: surface(
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: MfSize.minTouch),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (titleTrailing != null) titleTrailing!,
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm, vertical: MfSpace.xxs),
              ),
            ),
            for (final a in actions) ...[
              const SizedBox(width: MfSpace.xs),
              surface(a),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bell icon with unread badge; opens the notifications sheet.
class MfNotificationsButton extends ConsumerWidget {
  const MfNotificationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsCountProvider);
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: count > 0 ? 'Notifications, $count unread' : 'Notifications',
      onPressed: () => showMfNotificationsSheet(context),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: cs.error,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

/// In-app notifications list (bottom sheet).
Future<void> showMfNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final notificationsAsync = ref.watch(notificationsProvider);
        final unread = ref.watch(unreadNotificationsCountProvider);
        final text = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MfSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.xs, MfSpace.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(header: true, child: Text('Notifications', style: text.titleLarge)),
                    ),
                    if (unread > 0)
                      TextButton(
                        onPressed: () => ref.read(markAllAsReadProvider),
                        child: const Text('Mark all as read'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: notificationsAsync.when(
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return const MfEmptyState(
                        compact: true,
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications yet',
                        message: 'Emergency updates and messages will appear here.',
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: MfSpace.xs),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: MfSpace.md),
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        if (n == null) return const SizedBox.shrink();
                        final bool isRead = n['isRead'] ?? false;
                        return ListTile(
                          leading: Icon(
                            isRead ? Icons.notifications_none_rounded : Icons.notifications_active_outlined,
                            color: isRead ? cs.onSurfaceVariant : cs.primary,
                          ),
                          title: Text(
                            n['title'] ?? 'Notification',
                            style: text.titleSmall?.copyWith(
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(n['body'] ?? ''),
                          trailing: !isRead
                              ? IconButton(
                                  tooltip: 'Mark as read',
                                  icon: const Icon(Icons.done_rounded),
                                  onPressed: () => ref.read(markAsReadProvider(n['id'])),
                                )
                              : null,
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(MfSpace.xl),
                    child: MfLoading(),
                  ),
                  error: (e, _) => MfErrorState(
                    compact: true,
                    message: 'Could not load notifications.',
                    onRetry: () => ref.invalidate(notificationsProvider),
                  ),
                ),
              ),
              const SizedBox(height: MfSpace.sm),
            ],
          ),
        );
      },
    ),
  );
}

/// Drag handle for bottom sheets.
class MfSheetHandle extends StatelessWidget {
  const MfSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MfSpace.sm),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
