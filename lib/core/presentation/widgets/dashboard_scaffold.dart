import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeting_brain/l10n/app_localizations.dart';

class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.currentRoute,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: body,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: _indexFromRoute(currentRoute),
              onDestinationSelected: (index) => _onNavigate(context, index),
              indicatorColor: theme.colorScheme.primary.withOpacity(0.1),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              height: 64,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.video_call_outlined),
                  selectedIcon: Icon(Icons.video_call, color: theme.colorScheme.primary),
                  label: l10n.meetings,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt, color: theme.colorScheme.primary),
                  label: l10n.tasks,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.notifications_none),
                  selectedIcon: Icon(Icons.notifications, color: theme.colorScheme.primary),
                  label: l10n.notifications,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _indexFromRoute(String route) {
    switch (route) {
      case '/meetings':
        return 0;
      case '/tasks':
        return 1;
      case '/notifications':
        return 2;
      default:
        return 0;
    }
  }

  void _onNavigate(BuildContext context, int index) {
    final paths = ['/meetings', '/tasks', '/notifications'];
    context.go(paths[index]);
  }
}
