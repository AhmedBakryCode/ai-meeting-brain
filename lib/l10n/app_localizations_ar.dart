// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get auth => 'المصادقة';

  @override
  String get meetings => 'الاجتماعات';

  @override
  String get tasks => 'المهام';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get authTitle => 'تسجيل الدخول';

  @override
  String get authSubtitle => 'سجّل الدخول بأمان إلى مساحة العمل الذكية.';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get continueText => 'متابعة';

  @override
  String get meetingsTitle => 'لوحة الاجتماعات';

  @override
  String get meetingsSubtitle =>
      'تابع التسجيلات والتفريغ وملخصات الذكاء الاصطناعي.';

  @override
  String get meeting => 'اجتماع';

  @override
  String get aiSummaryPending => 'يتم تجهيز الملخص الذكي...';

  @override
  String get tasksTitle => 'لوحة المهام';

  @override
  String get tasksSubtitle => 'تابع عناصر العمل التي يولدها الذكاء الاصطناعي.';

  @override
  String get prepareWeeklySummary => 'إعداد ملخص الاجتماعات الأسبوعي';

  @override
  String get sendClientRecap => 'إرسال ملخص للعميل';

  @override
  String get reviewActionItems => 'مراجعة مهام الفريق';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsSubtitle => 'ابقَ على اطلاع بتحديثات المساعد المهمة.';

  @override
  String get notificationMeetingStartsSoon =>
      'سيبدأ اجتماع الاستراتيجية خلال 10 دقائق.';

  @override
  String get notificationTaskReminder => 'تذكير: 3 مهام معلقة من الأمس.';

  @override
  String get notificationSummaryReady =>
      'ملخص الذكاء الاصطناعي لاجتماع مزامنة المنتج جاهز.';
}
