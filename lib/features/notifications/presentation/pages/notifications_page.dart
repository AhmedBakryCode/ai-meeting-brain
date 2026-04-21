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
                    final message = item['message'] ?? '';
                    final type = item['type'] ?? '';
                    final id = item['id'] ?? '';
                    final meetingId = item['meetingId'] ??
                        item['entityId'] ??
                        item['referenceId'] ??
                        item['relatedEntityId'] ??
                        '';
                    final isMeeting = type == 'MeetingStarted' || type == 'MeetingInvited' || meetingId.toString().isNotEmpty;
                    
                    DateTime? createdAt;
                    if (item['createdAt'] != null) {
                      try {
                        createdAt = DateTime.parse(item['createdAt'].toString());
                      } catch (_) {}
                    }

                    return _NotificationCard(
                      title: title,
                      message: message,
                      date: createdAt,
                      isMeeting: isMeeting,
                      onTap: () {
                         _remoteDataSource.markAsRead(id);
                         final meetingQuery = isMeeting && meetingId.toString().isNotEmpty && meetingId != 'null'
                             ? '&meetingId=${Uri.encodeComponent(meetingId.toString())}'
                             : '';
                         context.push(
                           '/notifications/details/$id${isMeeting ? "?isMeeting=true$meetingQuery" : ""}',
                         );
                      },
                    );
                  },
                ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.message,
    this.date,
    this.isMeeting = false,
    this.onTap,
  });
  
  final String title;
  final String message;
  final DateTime? date;
  final bool isMeeting;
  final VoidCallback? onTap;

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isMeeting ? theme.colorScheme.primary : theme.colorScheme.secondary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMeeting ? Icons.video_call_rounded : Icons.notifications_active_outlined,
              color: isMeeting ? theme.colorScheme.primary : theme.colorScheme.secondary,
              size: 24,
            ),
          ),
          title: Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (message.isNotEmpty)
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              if (date != null) ...[
                const SizedBox(height: 6),
                Text(
                  _formatDate(date!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.2)),
        ),
      ),
    );
  }
}
