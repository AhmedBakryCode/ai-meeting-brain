import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection_container.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/meetings/presentation/pages/live_meeting_page.dart';
import '../../features/meetings/presentation/pages/meetings_page.dart';
import '../../features/notifications/presentation/pages/notification_details_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/tasks/presentation/pages/task_details_page.dart';
import '../../features/tasks/presentation/pages/tasks_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/meetings',
    redirect: (context, state) {
      final authDataSource = sl<AuthLocalDataSource>();
      final token = authDataSource.getAccessToken();
      final isAuthenticated = token != null && token.isNotEmpty;
      
      final isAuthRoute = state.matchedLocation == '/auth' || state.matchedLocation == '/register';
      
      if (!isAuthenticated && !isAuthRoute) {
        return '/auth';
      }
      if (isAuthenticated && isAuthRoute) {
        return '/meetings';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/auth',
        name: 'auth',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const AuthPage(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const RegisterPage(),
        ),
      ),
      GoRoute(
        path: '/meetings',
        name: 'meetings',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const MeetingsPage(),
        ),
      ),
      GoRoute(
        path: '/meetings/live/:id',
        name: 'live-meeting',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: LiveMeetingPage(
            meetingId: state.pathParameters['id'] ?? '',
            canUploadRecording: state.uri.queryParameters['canUpload'] != 'false',
          ),
        ),
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const TasksPage(),
        ),
        routes: [
          GoRoute(
            path: 'details/:id',
            name: 'task-details',
            pageBuilder: (context, state) => _buildTransitionPage(
              state: state,
              child: TaskDetailsPage(taskId: state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const NotificationsPage(),
        ),
        routes: [
          GoRoute(
            path: 'details/:id',
            name: 'notification-details',
            pageBuilder: (context, state) => _buildTransitionPage(
              state: state,
              child: NotificationDetailsPage(
                notificationId: state.pathParameters['id'] ?? '',
                isMeeting: state.uri.queryParameters['isMeeting'] == 'true',
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const ProfilePage(),
        ),
      ),
    ],
  );

  static CustomTransitionPage<void> _buildTransitionPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
    );
  }
}
