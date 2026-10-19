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
  String get success => 'تم بنجاح';

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
  String get parent => 'ولي الأمر';

  @override
  String get child => 'الطفل';

  @override
  String get security => 'الأمان';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

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
  String get privacyPolicySubtitle => 'اقرأ التزاماتنا بشأن أمان البيانات';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get termsOfServiceSubtitle => 'الشروط والإرشادات القياسية';

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
  String get children => 'الأبناء';

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
  String get familySafe => 'عائلتك في أمان تام الآن';

  @override
  String get childSafe => 'أنت بأمان وحماية كاملة الآن';

  @override
  String get limits => 'الحدود';

  @override
  String get enforced => 'مُطبّق';

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
  String get emptyStates => 'لا يوجد شيء هنا بعد';

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
  String get tooManyRequests => 'محاولات كثيرة جداً. يرجى المحاولة لاحقاً';

  @override
  String get networkError => 'خطأ في الشبكة. يرجى التحقق من اتصالك';

  @override
  String get reauthRequired => 'يرجى تسجيل الدخول مجدداً للمتابعة';

  @override
  String get changePasswordDescription =>
      'أدخل كلمة المرور الحالية والجديدة لتحديث بياناتك';

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

  @override
  String get errorLoadingDashboard => 'فشل تحميل لوحة التحكم';

  @override
  String get allProtectionsOn => 'جميع أنظمة الحماية مفعلة';

  @override
  String get familySafeNow => 'عائلتك في أمان\nالآن';

  @override
  String get protectedDevice => 'جهاز محمي';

  @override
  String get noChildrenConnectedYet => 'لا يوجد أطفال متصلون بعد';

  @override
  String get noChildrenDescription =>
      'اربط هاتف طفلك بمسح سريع لرمز QR لبدء الحماية.';

  @override
  String get parentAccount => 'حساب ولي الأمر';

  @override
  String get protectedParentPortal => 'بوابة الوالدين الآمنة';

  @override
  String get settingsProfileSubtitle => 'تعديل الاسم والأمان والمظهر واللغة';

  @override
  String get settingsPairSubtitle => 'إنشاء رمز QR لإعداد هاتف الطفل';

  @override
  String get settingsSwitchRoleSubtitle => 'التبديل بين وضع ولي الأمر والطفل';

  @override
  String get settingsDevicePermissionsSubtitle =>
      'التحقق من حالة مراقبة النظام والأذونات';

  @override
  String get darkNavyPalette => 'السمة الكحلية الداكنة';

  @override
  String get darkNavyDescription => 'مظهر كحلي داكن موحد لجميع الشاشات';

  @override
  String get lightThemeEnabled => 'تم تفعيل الوضع الفاتح';

  @override
  String get pending => 'معلق';

  @override
  String get approved => 'تمت الموافقة';

  @override
  String get denied => 'مرفوض';

  @override
  String get all => 'الكل';

  @override
  String get familyControls => 'عناصر تحكم العائلة';

  @override
  String get parentDashboard => 'لوحة تحكم الرقابة الأبوية';

  @override
  String get familyLocations => 'مواقع العائلة';

  @override
  String get liveGpsTracking => 'تتبع GPS المباشر';

  @override
  String get appRequests => 'طلبات التطبيقات';

  @override
  String get approveOrDenyRequests => 'الموافقة على وصول الطفل أو رفضه';

  @override
  String get educationCenter => 'مركز التعليم';

  @override
  String get manageLearningMaterials => 'إدارة وتتبع المواد التعليمية';

  @override
  String get uploadMaterial => 'رفع مادة تعليمية';

  @override
  String get realTimeAlerts => 'تنبيهات وأذونات في الوقت الفعلي';

  @override
  String get markAllAsRead => 'تحديد الكل كمقروء';

  @override
  String get openNativeMaps => 'فتح في الخرائط';

  @override
  String get aboutSmartGuard => 'حول الحارس الذكي';

  @override
  String get smartGuardDescription => 'يحافظ FamilyGuard على توازن وأمان جهازك';

  @override
  String get gotIt => 'حسناً، فهمت!';

  @override
  String get familyGroup => 'مجموعة العائلة';

  @override
  String get familyGroupConnected => 'متصل بالوالدين';

  @override
  String get familyGroupScanPrompt => 'امسح رمز QR الخاص بولي الأمر للربط';

  @override
  String get aboutSmartGuardSubtitle =>
      'كيف تحافظ الحدود الرقمية الصحية على أمانك';

  @override
  String get noChildrenLinkedYet => 'لا يوجد أطفال مرتبطون حتى الآن';

  @override
  String get noPendingRequests => 'لا توجد طلبات معلقة';

  @override
  String get noNotificationsYet => 'لا توجد إشعارات جديدة';
}
