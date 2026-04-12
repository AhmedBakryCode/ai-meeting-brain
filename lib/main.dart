import 'package:bloc/bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/notifications/notification_service.dart';
import 'core/observer/app_bloc_observer.dart';
import 'core/sync/sync_manager.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/meetings/domain/repositories/meetings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var isFirebaseReady = false;
  try {
    await Firebase.initializeApp();
    isFirebaseReady = true;
  } catch (e, stackTrace) {
    // Keep app booting in environments where Firebase files are not configured yet.
    debugPrint('Firebase initialization skipped: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
  await Hive.initFlutter();
  await AuthLocalDataSourceImpl.init();
  tz_data.initializeTimeZones();
  Bloc.observer = AppBlocObserver();
  await configureDependencies();
  if (isFirebaseReady) {
    final notificationService = sl<NotificationService>();
    await notificationService.initialize();
    FirebaseMessaging.onMessage.listen(notificationService.showForegroundNotification);
  }
  sl<SyncManager>().start(
    onConnected: () => sl<MeetingsRepository>().syncPendingData(),
  );
  runApp(const MeetingBrainApp());
}
