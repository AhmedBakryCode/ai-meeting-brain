// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get auth => 'Auth';

  @override
  String get meetings => 'Meetings';

  @override
  String get tasks => 'Tasks';

  @override
  String get notifications => 'Notifications';

  @override
  String get authTitle => 'Authentication';

  @override
  String get authSubtitle => 'Securely sign in to your AI-powered workspace.';

  @override
  String get signIn => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get continueText => 'Continue';

  @override
  String get meetingsTitle => 'Meetings Dashboard';

  @override
  String get meetingsSubtitle =>
      'Track recordings, transcriptions, and AI summaries.';

  @override
  String get meeting => 'Meeting';

  @override
  String get aiSummaryPending => 'AI summary is being prepared...';

  @override
  String get tasksTitle => 'Task Board';

  @override
  String get tasksSubtitle => 'Follow up on AI-generated action items.';

  @override
  String get prepareWeeklySummary => 'Prepare weekly meeting summary';

  @override
  String get sendClientRecap => 'Send client recap email';

  @override
  String get reviewActionItems => 'Review team action items';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle => 'Stay on top of key assistant updates.';

  @override
  String get notificationMeetingStartsSoon =>
      'Your strategy meeting starts in 10 minutes.';

  @override
  String get notificationTaskReminder =>
      'Reminder: 3 pending tasks from yesterday.';

  @override
  String get notificationSummaryReady =>
      'AI summary for Product Sync is ready.';
}
