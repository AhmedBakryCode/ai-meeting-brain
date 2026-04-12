import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeting_brain/l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/widgets/dashboard_scaffold.dart';
import '../../data/datasources/notifications_remote_data_source.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _remoteDataSource = sl<NotificationsRemoteDataSource>();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final items = await _remoteDataSource.fetchNotifications();
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DashboardScaffold(
      title: l10n.notificationsTitle,
      subtitle: l10n.notificationsSubtitle,
      currentRoute: '/notifications',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(child: Text(l10n.notificationsSubtitle))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final title = item['title'] ?? 'Notification';
                    final type = item['type'] ?? '';
                    final id = item['id'] ?? '';
                    final isMeeting = type == 'MeetingStarted';
                    
                    return _NotificationCard(
                      text: title,
                      isMeeting: isMeeting,
                      onTap: () {
                         _remoteDataSource.markAsRead(id);
                         context.push('/notifications/details/$id${isMeeting ? "?isMeeting=true" : ""}');
                      },
                    );
                  },
                ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.text, this.isMeeting = false, this.onTap});
  final String text;
  final bool isMeeting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isMeeting ? theme.colorScheme.primary : theme.colorScheme.secondary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMeeting ? Icons.video_call_rounded : Icons.notifications_active_outlined,
              color: isMeeting ? theme.colorScheme.primary : theme.colorScheme.secondary,
              size: 20,
            ),
          ),
          title: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.2)),
        ),
      ),
    );
  }
}
