import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meeting_brain/l10n/app_localizations.dart';

import 'core/di/injection_container.dart';
import 'core/presentation/cubit/app_settings_cubit.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class MeetingBrainApp extends StatelessWidget {
  const MeetingBrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AppSettingsCubit>(),
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, state) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Meeting Brain',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            locale: state.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
