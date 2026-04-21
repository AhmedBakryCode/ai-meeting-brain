import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../../meetings/data/datasources/meetings_remote_data_source.dart';

class NotificationDetailsPage extends StatelessWidget {
  const NotificationDetailsPage({
    required this.notificationId,
    this.meetingId,
    this.isMeeting = false,
    super.key,
  });

  final String notificationId;
  final String? meetingId;
  final bool isMeeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMeeting
                              ? Icons.video_call
                              : Icons.notifications_active,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        isMeeting ? 'Meeting Reminder' : 'Update',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isMeeting
                        ? 'The weekly coordination meeting is starting in 5 minutes. Please join to stay updated with the team.'
                        : 'You have a new update regarding your recent task summary.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (isMeeting)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final router = GoRouter.of(context);
                    final resolvedMeetingId = meetingId;
                    if (resolvedMeetingId == null ||
                        resolvedMeetingId.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Meeting id is missing in this notification.',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      final response = await sl<MeetingsRemoteDataSource>()
                          .joinMeeting(resolvedMeetingId);
                      final canUpload = _isCurrentUserCreator(response);
                      if (!context.mounted) return;
                      router.push(
                        '/meetings/live/$resolvedMeetingId?canUpload=$canUpload&joined=true',
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to start meeting: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.video_call),
                  label: const Text('Join Meeting Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentUserCreator(Map<String, dynamic> response) {
    final meeting = response['meeting'];
    if (meeting is! Map<String, dynamic>) return false;

    final creatorId = meeting['creatorId']?.toString();
    final creatorName = meeting['creatorName']?.toString();
    final authDataSource = sl<AuthLocalDataSource>();
    final currentIdentifiers = authDataSource.extractUserIdentifiersFromToken(
      authDataSource.getAccessToken(),
    );

    if (currentIdentifiers.isEmpty) return false;

    return currentIdentifiers.contains(creatorId?.trim().toLowerCase()) ||
        currentIdentifiers.contains(creatorName?.trim().toLowerCase());
  }
}
