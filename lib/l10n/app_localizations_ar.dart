// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'FamilyGuard';

  @override
  String get welcome => 'مرحباً';

  @override
  String get home => 'الرئيسية';

  @override
  String get control => 'التحكم';

  @override
  String get location => 'الموقع';

  @override
  String get requests => 'الطلبات';

  @override
  String get alerts => 'التنبيهات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get settings => 'الإعدادات';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get language => 'اللغة';

  @override
  String get loading => 'جار التحميل...';

  @override
  String get error => 'خطأ';

  @override
  String get success => 'نجاح';

  @override
  String get chooseLanguage => 'اختر لغتك المفضلة';

  @override
  String languageChangedTo(String language) {
    return 'تم تغيير اللغة إلى $language';
  }

  @override
  String get profileSettings => 'الملف الشخصي والإعدادات';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get personalInfo => 'المعلومات الشخصية';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get emailAddress => 'عنوان البريد الإلكتروني';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get role => 'الدور';

  @override
  String get parent => 'والد';

  @override
  String get child => 'طفل';

  @override
  String get security => 'الأمان';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get accountSettings => 'إعدادات الحساب';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get pushNotifications => 'الإشعارات الفورية';

  @override
  String get appearance => 'المظهر';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get appVersion => 'إصدار التطبيق';

  @override
  String get accountActions => 'إجراءات الحساب';

  @override
  String get deleteAccount => 'حذف الحساب والبيانات';

  @override
  String get signOutConfirmTitle => 'تسجيل الخروج';

  @override
  String get signOutConfirmMessage => 'هل أنت متأكد من رغبتك في تسجيل الخروج؟';

  @override
  String get deleteAccountConfirmTitle => 'حذف الحساب';

  @override
  String get deleteAccountConfirmMessage =>
      'هذا الإجراء دائم. أدخل كلمة المرور للتأكيد.';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get password => 'كلمة المرور';

  @override
  String get saveNewPassword => 'حفظ كلمة المرور الجديدة';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور بنجاح';

  @override
  String get passwordResetSent => 'تم إرسال بريد إعادة تعيين كلمة المرور';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get children => 'الأطفال';

  @override
  String get addChild => '+ إضافة طفل';

  @override
  String get protected => 'محمي';

  @override
  String get online => 'متصل';

  @override
  String get offline => 'غير متصل';

  @override
  String get rules => 'القواعد';

  @override
  String get lessons => 'الدروس';

  @override
  String get family => 'العائلة';

  @override
  String get familySafe => 'عائلتك آمنة الآن';

  @override
  String get childSafe => 'أنت آمن ومحمي الآن';

  @override
  String get limits => 'الحدود';

  @override
  String get enforced => 'مُنفذ';

  @override
  String get gps => 'GPS';

  @override
  String get live => 'مباشر';

  @override
  String get approvals => 'الموافقات';

  @override
  String get instant => 'فوري';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get myProfile => 'ملفي الشخصي وحسابي';

  @override
  String get switchRole => 'تبديل الدور';

  @override
  String get pairChildDevice => 'ربط جهاز الطفل';

  @override
  String get devicePermissions => 'أذونات الجهاز';

  @override
  String get myLearning => 'تعليمي';

  @override
  String get myProtection => 'حمايتي';

  @override
  String get apps => 'التطبيقات';

  @override
  String get health => 'الصحة';

  @override
  String get setup => 'الإعداد';

  @override
  String get openLessons => 'فتح الدروس';

  @override
  String get pendingLessons => 'دروس معلقة';

  @override
  String get noChildren => 'لا يوجد أطفال مرتبطون';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get noRequests => 'لا توجد طلبات معلقة';

  @override
  String get emptyStates => 'لا شيء هنا بعد';

  @override
  String get session => 'الجلسة';

  @override
  String get welcomeMessage => 'مرحباً بعودتك،';

  @override
  String get subTitle => 'آمن. متصل. معاً.';

  @override
  String get currentPasswordRequired => 'كلمة المرور الحالية مطلوبة';

  @override
  String get newPasswordRequired => 'كلمة المرور الجديدة مطلوبة';

  @override
  String get passwordMinLength => 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';

  @override
  String get passwordsDoNotMatch => 'كلمات المرور غير متطابقة';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب';

  @override
  String get invalidEmail => 'بريد إلكتروني غير صالح';

  @override
  String get wrongPassword => 'كلمة المرور غير صحيحة';

  @override
  String get userNotFound => 'لم يتم العثور على حساب بهذا البريد';

  @override
  String get tooManyRequests => 'محاولات كثيرة جداً. حاول مرة أخرى لاحقاً.';

  @override
  String get networkError => 'خطأ في الشبكة. تحقق من اتصالك.';

  @override
  String get reauthRequired => 'يرجى تسجيل الدخول مرة أخرى للمتابعة';

  @override
  String get changePasswordDescription =>
      'أدخل كلمة المرور الحالية وكلمة مرور جديدة';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get noResults => 'لم يتم العثور على نتائج';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get delete => 'حذف';

  @override
  String get update => 'تحديث';

  @override
  String get close => 'إغلاق';

  @override
  String get back => 'رجوع';

  @override
  String get next => 'التالي';

  @override
  String get done => 'تم';

  @override
  String get skip => 'تخطي';

  @override
  String get or => 'أو';

  @override
  String get and => 'و';

  @override
  String get send => 'إرسال';

  @override
  String get search => 'بحث';

  @override
  String get filter => 'تصفية';

  @override
  String get sort => 'ترتيب';

  @override
  String get refresh => 'تحديث';

  @override
  String get updating => 'جار التحديث...';

  @override
  String get saving => 'جار الحفظ...';
}
