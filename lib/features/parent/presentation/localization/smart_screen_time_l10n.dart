import 'package:flutter/material.dart';

/// Reusable localization module for Smart Screen Time & Habit Scheduling.
/// Supports English ('en'), Afaan Oromoo ('om'), Amharic ('am'), and Arabic ('ar').
class SmartScreenTimeL10n {
  final String languageCode;

  const SmartScreenTimeL10n(this.languageCode);

  static SmartScreenTimeL10n of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return SmartScreenTimeL10n(code);
  }

  bool get isRtl => languageCode == 'ar';

  String get screenTitle {
    switch (languageCode) {
      case 'am':
        return 'ብልህ የስክሪን ጊዜ';
      case 'om':
        return 'Yeroo Iskiriinii Qaraa';
      case 'ar':
        return 'وقت الشاشة الذكي';
      default:
        return 'Smart Screen Time';
    }
  }

  String get dailyLimitTitle {
    switch (languageCode) {
      case 'am':
        return 'የዕለት የስክሪን ጊዜ ገደብ';
      case 'om':
        return 'Daangaa Yeroo Iskiriinii Guyyaa';
      case 'ar':
        return 'الحد اليومي لوقت الشاشة';
      default:
        return 'Daily Screen Time Limit';
    }
  }

  String get dailyLimitHeader {
    switch (languageCode) {
      case 'am':
        return 'የዕለት ገደብ';
      case 'om':
        return 'Daangaa Guyyaa';
      case 'ar':
        return 'الحد اليومي';
      default:
        return 'Daily Limit';
    }
  }

  String maxPerDay(String time) {
    switch (languageCode) {
      case 'am':
        return 'በቀን ከፍተኛው $time';
      case 'om':
        return 'Guyyaatti ol\'aanaa $time';
      case 'ar':
        return 'الحد الأقصى $time يومياً';
      default:
        return 'Max $time per day';
    }
  }

  String get notSetTapToConfigure {
    switch (languageCode) {
      case 'am':
        return 'አልተዘጋጀም — ለማዘጋጀት ይጫኑ';
      case 'om':
        return 'Hinjijjiiramne — qindeessuuf tuqi';
      case 'ar':
        return 'غير محدد — انقر للضبط';
      default:
        return 'Not set — tap to configure';
    }
  }

  String warnBeforeLimit(int minutes) {
    switch (languageCode) {
      case 'am':
        return 'ከገደቡ $minutes ደቂቃ በፊት አስጠንቅቅ';
      case 'om':
        return 'Daangaa dura daqiiqaa $minutes akeekkachiisi';
      case 'ar':
        return 'تنبيه قبل $minutes دقيقة من الحد';
      default:
        return 'Warn ${minutes}m before limit';
    }
  }

  String totalScreenTimeFor(String childName) {
    switch (languageCode) {
      case 'am':
        return 'የ$childName አጠቃላይ የመሳሪያ ስክሪን ጊዜ';
      case 'om':
        return 'Yeroo iskiriinii meeshaa guutuu ${childName}tiif';
      case 'ar':
        return 'إجمالي وقت استخدام الشاشة لـ $childName';
      default:
        return 'Total device screen time for $childName';
    }
  }

  String get bedtimeTitle {
    switch (languageCode) {
      case 'am':
        return 'የመኝታ ሰዓት መርሐግብር';
      case 'om':
        return 'Sagantaa Yeroo Rafuu';
      case 'ar':
        return 'جدول وقت النوم';
      default:
        return 'Bedtime Schedule';
    }
  }

  String bedtimeFor(String childName) {
    switch (languageCode) {
      case 'am':
        return 'ለ$childName ፀጥታ ሰዓት ያዘጋጁ';
      case 'om':
        return '${childName}tiif yeroo cal-dhabaa qindeessi';
      case 'ar':
        return 'تحديد ساعات الهدوء لـ $childName';
      default:
        return 'Set quiet hours for $childName';
    }
  }

  String get bedtimeLabel {
    switch (languageCode) {
      case 'am':
        return 'የመኝታ ሰዓት';
      case 'om':
        return 'Yeroo Rafuu';
      case 'ar':
        return 'وقت النوم';
      default:
        return 'Bedtime';
    }
  }

  String get wakeUpLabel {
    switch (languageCode) {
      case 'am':
        return 'የመነሻ ሰዓት';
      case 'om':
        return 'Yeroo Ka\'uu';
      case 'ar':
        return 'وقت الاستيقاظ';
      default:
        return 'Wake up';
    }
  }

  String get deviceLockedOutsideHours {
    switch (languageCode) {
      case 'am':
        return 'ከተፈቀደው ሰዓት ውጭ መሳሪያው ይቆለፋል።';
      case 'om':
        return 'Yeroo hayyamameen ala meeshaan ni cufama.';
      case 'ar':
        return 'سيتم قفل الجهاز خارج الساعات المسموح بها.';
      default:
        return 'Device will be locked outside allowed hours.';
    }
  }

  String get applyOnDays {
    switch (languageCode) {
      case 'am':
        return 'የሚተገበርባቸው ቀናት:';
      case 'om':
        return 'Guyyoota itti hojiirra oolu:';
      case 'ar':
        return 'تطبيق في أيام:';
      default:
        return 'Apply on:';
    }
  }

  String get focusBlocksTitle {
    switch (languageCode) {
      case 'am':
        return 'የትኩረት ጊዜያት';
      case 'om':
        return 'Yeroowwan Xiyyeeffannoo';
      case 'ar':
        return 'فترات التركيز';
      default:
        return 'Focus Blocks';
    }
  }

  String get focusBlockSingular {
    switch (languageCode) {
      case 'am':
        return 'የትኩረት ጊዜ';
      case 'om':
        return 'Yeroo Xiyyeeffannoo';
      case 'ar':
        return 'فترة التركيز';
      default:
        return 'Focus Block';
    }
  }

  String get blockDistractions {
    switch (languageCode) {
      case 'am':
        return 'በዚህ ሰዓት ትኩረት የሚከፋፍሉ መተግበሪያዎችን አግድ።';
      case 'om':
        return 'Yeroo kana keessatti appiiwwan jeeqan ugguri.';
      case 'ar':
        return 'حظر التطبيقات المشتتة خلال هذه الفترة.';
      default:
        return 'Block distracting apps during this window.';
    }
  }

  String get blockNameLabel {
    switch (languageCode) {
      case 'am':
        return 'የትኩረት ስም';
      case 'om':
        return 'Maqaa xiyyeeffannoo';
      case 'ar':
        return 'اسم الفترة';
      default:
        return 'Block name';
    }
  }

  String get defaultFocusBlockName {
    switch (languageCode) {
      case 'am':
        return 'የጥናት ትኩረት';
      case 'om':
        return 'Qo\'annoo Xiyyeeffannoo';
      case 'ar':
        return 'التركيز على الدراسة';
      default:
        return 'Study Focus';
    }
  }

  String get startLabel {
    switch (languageCode) {
      case 'am':
        return 'መጀመሪያ';
      case 'om':
        return 'Jalqaba';
      case 'ar':
        return 'البدء';
      default:
        return 'Start';
    }
  }

  String get endLabel {
    switch (languageCode) {
      case 'am':
        return 'መጨረሻ';
      case 'om':
        return 'Dhuma';
      case 'ar':
        return 'الانتهاء';
      default:
        return 'End';
    }
  }

  String get addFocusBlockAction {
    switch (languageCode) {
      case 'am':
        return 'የትኩረት ጊዜ አክል';
      case 'om':
        return 'Yeroo Xiyyeeffannoo Dabaladhu';
      case 'ar':
        return 'إضافة فترة تركيز';
      default:
        return 'Add Focus Block';
    }
  }

  String get addAction {
    switch (languageCode) {
      case 'am':
        return 'አክል';
      case 'om':
        return 'Dabaladhu';
      case 'ar':
        return 'إضافة';
      default:
        return 'Add';
    }
  }

  String get noFocusBlocksTitle {
    switch (languageCode) {
      case 'am':
        return 'ምንም የትኩረት ጊዜ አልተዘጋጀም';
      case 'om':
        return 'Yeroon xiyyeeffannoo hin jiru';
      case 'ar':
        return 'لا توجد فترات تركيز بعد';
      default:
        return 'No focus blocks yet';
    }
  }

  String get addStudyWindowSubtitle {
    switch (languageCode) {
      case 'am':
        return 'ትኩረት እንዳይከፋፈል የጥናት ሰዓት ያዘጋጁ';
      case 'om':
        return 'Jeeqama ittisuuf yeroo qo\'annoo dabaladhu';
      case 'ar':
        return 'أضف فترة دراسة لمنع التشتت';
      default:
        return 'Add a study window to block distractions';
    }
  }

  String get appTimeLimitsTitle {
    switch (languageCode) {
      case 'am':
        return 'የመተግበሪያ ጊዜ ገደቦች';
      case 'om':
        return 'Daangaa Yeroo Appii';
      case 'ar':
        return 'حدود وقت التطبيقات';
      default:
        return 'App Time Limits';
    }
  }

  String get noAppLimitsTitle {
    switch (languageCode) {
      case 'am':
        return 'ምንም የመተግበሪያ ገደቦች የሉም';
      case 'om':
        return 'Daangaan appii hin jiru';
      case 'ar':
        return 'لا توجد حدود للتطبيقات';
      default:
        return 'No per-app limits';
    }
  }

  String get setAppLimitsFromManagementSubtitle {
    switch (languageCode) {
      case 'am':
        return 'የመተግበሪያ ገደቦችን ከመተግበሪያ ማስተዳደሪያ ገጽ ያዘጋጁ';
      case 'om':
        return 'Daangaa appii fuula bulchiinsa appii irraa qindeessi';
      case 'ar':
        return 'قم بتعيين حدود التطبيقات من شاشة إدارة التطبيقات';
      default:
        return 'Set per-app limits from the App Management screen';
    }
  }

  String get activeRulesStat {
    switch (languageCode) {
      case 'am':
        return 'ንቁ ደንቦች';
      case 'om':
        return 'Seerota hojiirra';
      case 'ar':
        return 'القواعد النشطة';
      default:
        return 'Active rules';
    }
  }

  String get dailyLimitStat {
    switch (languageCode) {
      case 'am':
        return 'የዕለት ገደብ';
      case 'om':
        return 'Daangaa guyyaa';
      case 'ar':
        return 'الحد اليومي';
      default:
        return 'Daily limit';
    }
  }

  String get bedtimeStat {
    switch (languageCode) {
      case 'am':
        return 'መኝታ ሰዓት';
      case 'om':
        return 'Yeroo Rafuu';
      case 'ar':
        return 'وقت النوم';
      default:
        return 'Bedtime';
    }
  }

  String get focusBlocksStat {
    switch (languageCode) {
      case 'am':
        return 'የትኩረት ጊዜ';
      case 'om':
        return 'Xiyyeeffannoo';
      case 'ar':
        return 'فترات التركيز';
      default:
        return 'Focus blocks';
    }
  }

  String get activeStatus {
    switch (languageCode) {
      case 'am':
        return 'ንቁ';
      case 'om':
        return 'Hojiirra';
      case 'ar':
        return 'نشط';
      default:
        return 'Active';
    }
  }

  String get pausedStatus {
    switch (languageCode) {
      case 'am':
        return 'የቆመ';
      case 'om':
        return 'Dhaabate';
      case 'ar':
        return 'متوقف مؤقتاً';
      default:
        return 'Paused';
    }
  }

  String get notSetStatus {
    switch (languageCode) {
      case 'am':
        return 'አልተዘጋጀም';
      case 'om':
        return 'Hinjijjiiramne';
      case 'ar':
        return 'غير محدد';
      default:
        return 'Not set';
    }
  }

  String get onStatus {
    switch (languageCode) {
      case 'am':
        return 'በርቷል';
      case 'om':
        return 'Bani';
      case 'ar':
        return 'مفعّل';
      default:
        return 'On';
    }
  }

  String get offStatus {
    switch (languageCode) {
      case 'am':
        return 'ጠፍቷል';
      case 'om':
        return 'Cufi';
      case 'ar':
        return 'معطّل';
      default:
        return 'Off';
    }
  }

  String get everyDay {
    switch (languageCode) {
      case 'am':
        return 'በየቀኑ';
      case 'om':
        return 'Guyyaa hunda';
      case 'ar':
        return 'كل يوم';
      default:
        return 'Every day';
    }
  }

  String get removeAction {
    switch (languageCode) {
      case 'am':
        return 'አስወግድ';
      case 'om':
        return 'Haqi';
      case 'ar':
        return 'إزالة';
      default:
        return 'Remove';
    }
  }

  String get saveAction {
    switch (languageCode) {
      case 'am':
        return 'አስቀምጥ';
      case 'om':
        return 'Olkaayi';
      case 'ar':
        return 'حفظ';
      default:
        return 'Save';
    }
  }

  String get retryAction {
    switch (languageCode) {
      case 'am':
        return 'እንደገና ሞክር';
      case 'om':
        return 'Irra deebi\'i';
      case 'ar':
        return 'إعادة المحاولة';
      default:
        return 'Retry';
    }
  }

  String get retryNowAction {
    switch (languageCode) {
      case 'am':
        return 'አሁን እንደገና ሞክር';
      case 'om':
        return 'Amma irra deebi\'i';
      case 'ar':
        return 'إعادة المحاولة الآن';
      default:
        return 'Retry Now';
    }
  }

  String get settingUpDatabaseTitle {
    switch (languageCode) {
      case 'am':
        return 'የውሂብ ጎታ እየተዘጋጀ ነው...';
      case 'om':
        return 'Kuusaan odeeffannoo qophaa\'aa jira...';
      case 'ar':
        return 'جارٍ إعداد قاعدة البيانات...';
      default:
        return 'Setting up database...';
    }
  }

  String get firestoreBuildingSubtitle {
    switch (languageCode) {
      case 'am':
        return 'ኢንዴክሶች ለመጀመሪያ ጊዜ እየተገነቡ ነው።\nይህ 1–2 ደቂቃ ይወስዳል። በራሱ እንደገና ይሞክራል።';
      case 'om':
        return 'Indaaksiin yeroo jalqabaaf ijaaramaa jira.\nKun daqiiqaa 1–2 fudhata. Ofumaan irra deebi\'a.';
      case 'ar':
        return 'يقوم Firestore ببناء الفهارس لأول مرة.\nيستغرق هذا حوالي 1-2 دقيقة. تتم إعادة المحاولة تلقائياً.';
      default:
        return 'Firestore is building indexes for the first time.\nThis takes about 1–2 minutes. Retrying automatically.';
    }
  }

  String get dailyLimitSavedSnack {
    switch (languageCode) {
      case 'am':
        return 'የዕለት ገደብ ተቀምጧል ✓';
      case 'om':
        return 'Daangaan guyyaa olkaa\'ameera ✓';
      case 'ar':
        return 'تم حفظ الحد اليومي ✓';
      default:
        return 'Daily limit saved ✓';
    }
  }

  String get dailyLimitRemovedSnack {
    switch (languageCode) {
      case 'am':
        return 'የዕለት ገደብ ተወግዷል';
      case 'om':
        return 'Daangaan guyyaa haqameera';
      case 'ar':
        return 'تمت إزالة الحد اليومي';
      default:
        return 'Daily limit removed';
    }
  }

  String get bedtimeSavedSnack {
    switch (languageCode) {
      case 'am':
        return 'የመኝታ መርሐግብር ተቀምጧል ✓';
      case 'om':
        return 'Sagantaan rafuu olkaa\'ameera ✓';
      case 'ar':
        return 'تم حفظ جدول وقت النوم ✓';
      default:
        return 'Bedtime schedule saved ✓';
    }
  }

  String get bedtimeRemovedSnack {
    switch (languageCode) {
      case 'am':
        return 'የመኝታ ደንብ ተወግዷል';
      case 'om':
        return 'Seerri rafuu haqameera';
      case 'ar':
        return 'تمت إزالة قاعدة وقت النوم';
      default:
        return 'Bedtime rule removed';
    }
  }

  String get focusSavedSnack {
    switch (languageCode) {
      case 'am':
        return 'የትኩረት ጊዜ ተቀምጧል ✓';
      case 'om':
        return 'Yeroon xiyyeeffannoo olkaa\'ameera ✓';
      case 'ar':
        return 'تم حفظ فترة التركيز ✓';
      default:
        return 'Focus block saved ✓';
    }
  }

  String get focusRemovedSnack {
    switch (languageCode) {
      case 'am':
        return 'የትኩረት ጊዜ ተወግዷል';
      case 'om':
        return 'Yeroon xiyyeeffannoo haqameera';
      case 'ar':
        return 'تمت إزالة فترة التركيز';
      default:
        return 'Focus block removed';
    }
  }

  String get selectAtLeastOneDaySnack {
    switch (languageCode) {
      case 'am':
        return 'እባክዎ ቢያንስ አንድ ቀን ይምረጡ';
      case 'om':
        return 'Mee yoo xiqqaate guyyaa tokko filadhu';
      case 'ar':
        return 'يرجى تحديد يوم واحد على الأقل';
      default:
        return 'Select at least one day';
    }
  }

  String get enterBlockNameSnack {
    switch (languageCode) {
      case 'am':
        return 'እባክዎ የትኩረት ስም ያስገቡ';
      case 'om':
        return 'Mee maqaa xiyyeeffannoo galchi';
      case 'ar':
        return 'يرجى إدخال اسم فترة التركيز';
      default:
        return 'Enter a block name';
    }
  }

  List<String> get dayLabelsShort {
    switch (languageCode) {
      case 'am':
        return ['ሰ', 'ማ', 'ረ', 'ሐ', 'አ', 'ቅ', 'እ'];
      case 'om':
        return ['W', 'K', 'R', 'K', 'J', 'S', 'D'];
      case 'ar':
        return ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
      default:
        return ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    }
  }

  List<String> get dayNamesMedium {
    switch (languageCode) {
      case 'am':
        return ['', 'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'አርብ', 'ቅዳሜ', 'እሁድ'];
      case 'om':
        return ['', 'Wiixata', 'Kibxata', 'Roobii', 'Kamisa', 'Jimaata', 'Sanbata', 'Dilbata'];
      case 'ar':
        return ['', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      default:
        return ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }
  }
}
