// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appName => 'FamilyGuard';

  @override
  String get welcome => 'እንኳን ደህና መጡ';

  @override
  String get home => 'መነሻ';

  @override
  String get control => 'ቁጥጥር';

  @override
  String get location => 'አቀማመጥ';

  @override
  String get requests => 'ጥያቄዎች';

  @override
  String get alerts => 'ማስጠንቀቂያዎች';

  @override
  String get profile => 'መገለጫ';

  @override
  String get settings => 'ቅንብሮች';

  @override
  String get save => 'አስቀምጥ';

  @override
  String get cancel => 'ሰርዝ';

  @override
  String get confirm => 'አረጋግጥ';

  @override
  String get signOut => 'ውጣ';

  @override
  String get changePassword => 'የይለፍ ቃል ቀይር';

  @override
  String get language => 'ቋንቋ';

  @override
  String get loading => 'በመጫን ላይ...';

  @override
  String get error => 'ስህተት';

  @override
  String get success => 'ተሳክቷል';

  @override
  String get chooseLanguage => 'የሚመርጡትን ቋንቋ ይምረጡ';

  @override
  String languageChangedTo(String language) {
    return 'ቋንቋ ወደ $language ተቀይሯል';
  }

  @override
  String get profileSettings => 'መገለጫ እና ቅንብሮች';

  @override
  String get editProfile => 'መገለጫ አርትዕ';

  @override
  String get personalInfo => 'የግል መረጃ';

  @override
  String get fullName => 'ሙሉ ስም';

  @override
  String get emailAddress => 'የኢሜይል አድራሻ';

  @override
  String get phoneNumber => 'የስልክ ቁጥር';

  @override
  String get role => 'ሚና';

  @override
  String get parent => 'ወላጅ';

  @override
  String get child => 'ልጅ';

  @override
  String get security => 'ደህንነት';

  @override
  String get resetPassword => 'የይለፍ ቃል ዳግም አስጀምር';

  @override
  String get forgotPassword => 'የይለፍ ቃል ረሱት?';

  @override
  String get accountSettings => 'የመለያ ቅንብሮች';

  @override
  String get notifications => 'ማሳወቂያዎች';

  @override
  String get pushNotifications => 'የስልክ ማሳወቂያዎች';

  @override
  String get appearance => 'መልክ';

  @override
  String get darkMode => 'ጨለማ ገጽታ';

  @override
  String get lightMode => 'ብርሃን ገጽታ';

  @override
  String get privacyPolicy => 'የግላዊነት ፖሊሲ';

  @override
  String get privacyPolicySubtitle => 'የውሂብ ደህንነት ቁርጠኝነታችንን ያንብቡ';

  @override
  String get termsOfService => 'የአገልግሎት ውሎች';

  @override
  String get termsOfServiceSubtitle => 'መደበኛ የአገልግሎት ውሎች እና መመሪያዎች';

  @override
  String get appVersion => 'የመተግበሪያ ስሪት';

  @override
  String get accountActions => 'የመለያ እርምጃዎች';

  @override
  String get deleteAccount => 'መለያ እና ውሂብ ሰርዝ';

  @override
  String get signOutConfirmTitle => 'መውጫ';

  @override
  String get signOutConfirmMessage => 'እርግጠኛ ነዎት መውጣት ይፈልጋሉ?';

  @override
  String get deleteAccountConfirmTitle => 'መለያ ሰርዝ';

  @override
  String get deleteAccountConfirmMessage =>
      'ይህ እርምጃ ዘላቂ ነው። ለማረጋገጥ የይለፍ ቃልዎን ያስገቡ።';

  @override
  String get currentPassword => 'የአሁኑ የይለፍ ቃል';

  @override
  String get newPassword => 'አዲስ የይለፍ ቃል';

  @override
  String get confirmNewPassword => 'አዲሱን የይለፍ ቃል ያረጋግጡ';

  @override
  String get password => 'የይለፍ ቃል';

  @override
  String get saveNewPassword => 'አዲሱን የይለፍ ቃል አስቀምጥ';

  @override
  String get passwordChanged => 'የይለፍ ቃል በተሳካ ሁኔታ ተቀይሯል';

  @override
  String get passwordResetSent => 'የይለፍ ቃል ዳግም ማስጀመሪያ ኢሜይል ተልኳል';

  @override
  String get profileUpdated => 'መገለጫ በተሳካ ሁኔታ ተስተካክሏል';

  @override
  String get children => 'ልጆች';

  @override
  String get addChild => '+ ልጅ ጨምር';

  @override
  String get protected => 'የተጠበቀ';

  @override
  String get online => 'ኦንላይን';

  @override
  String get offline => 'ኦፍላይን';

  @override
  String get rules => 'ደንቦች';

  @override
  String get lessons => 'ትምህርቶች';

  @override
  String get family => 'ቤተሰብ';

  @override
  String get familySafe => 'ቤተሰብዎ አሁን ደህንነቱ የተጠበቀ ነው';

  @override
  String get childSafe => 'አሁን ሙሉ በሙሉ ደህንነትዎ የተጠበቀ ነው';

  @override
  String get limits => 'ገደቦች';

  @override
  String get enforced => 'ተግባራዊ ተደርጓል';

  @override
  String get gps => 'GPS';

  @override
  String get live => 'ቀጥታ';

  @override
  String get approvals => 'ማፅደቂያዎች';

  @override
  String get instant => 'ፈጣን';

  @override
  String get dashboard => 'ዳሽቦርድ';

  @override
  String get myProfile => 'የእኔ መገለጫ እና መለያ';

  @override
  String get switchRole => 'ሚና ቀይር';

  @override
  String get pairChildDevice => 'የልጅ መሣሪያ ያገናኙ';

  @override
  String get devicePermissions => 'የመሣሪያ ፈቃዶች';

  @override
  String get myLearning => 'የትምህርት ገጼ';

  @override
  String get myProtection => 'የእኔ ጥበቃ';

  @override
  String get apps => 'መተግበሪያዎች';

  @override
  String get health => 'ጤና';

  @override
  String get setup => 'አዋቅር';

  @override
  String get openLessons => 'ትምህርት ክፈት';

  @override
  String get pendingLessons => 'ያልተጠናቀቁ ትምህርቶች';

  @override
  String get noChildren => 'የተገናኙ ልጆች የሉም';

  @override
  String get noNotifications => 'ምንም ማሳወቂያ የለም';

  @override
  String get noRequests => 'ምንም ጥያቄ የለም';

  @override
  String get emptyStates => 'እዚህ ምንም ነገር የለም';

  @override
  String get session => 'ክፍለ-ጊዜ';

  @override
  String get welcomeMessage => 'እንኳን ደህና መጡ፣';

  @override
  String get subTitle => 'ደህንነት። ግንኙነት። አንድነት።';

  @override
  String get currentPasswordRequired => 'የአሁኑ የይለፍ ቃል ያስፈልጋል';

  @override
  String get newPasswordRequired => 'አዲስ የይለፍ ቃል ያስፈልጋል';

  @override
  String get passwordMinLength => 'የይለፍ ቃል ቢያንስ 6 ፊደላት መሆን አለበት';

  @override
  String get passwordsDoNotMatch => 'የይለፍ ቃሎቹ አይዛመዱም';

  @override
  String get fieldRequired => 'ይህ ክፍተት መሞላት አለበት';

  @override
  String get invalidEmail => 'ልክ ያልሆነ የኢሜይል አድራሻ';

  @override
  String get wrongPassword => 'የተሳሳተ የይለፍ ቃል';

  @override
  String get userNotFound => 'በዚህ ኢሜይል የተመዘገበ መለያ የለም';

  @override
  String get tooManyRequests => 'ብዙ ሙከራዎች ተደርገዋል። እባክዎ ቆይተው እንደገና ይሞክሩ';

  @override
  String get networkError => 'የበይነመረብ ስህተት። እባክዎ ግንኙነትዎን ያረጋግጡ';

  @override
  String get reauthRequired => 'ለመቀጠል እባክዎ እንደገና ይግቡ';

  @override
  String get changePasswordDescription => 'የአሁኑን እና አዲሱን የይለፍ ቃል በማስገባት ያዘምኑ';

  @override
  String get appLanguage => 'የመተግበሪያ ቋንቋ';

  @override
  String get selectLanguage => 'ቋንቋ ይምረጡ';

  @override
  String get noResults => 'ምንም ውጤት አልተገኘም';

  @override
  String get retry => 'እንደገና ሞክር';

  @override
  String get delete => 'ሰርዝ';

  @override
  String get update => 'አዘምን';

  @override
  String get close => 'ዝጋ';

  @override
  String get back => 'ተመለስ';

  @override
  String get next => 'ቀጣይ';

  @override
  String get done => 'ተጠናቋል';

  @override
  String get skip => 'ዝለል';

  @override
  String get or => 'ወይም';

  @override
  String get and => 'እና';

  @override
  String get send => 'ላክ';

  @override
  String get search => 'ፈልግ';

  @override
  String get filter => 'አጣራ';

  @override
  String get sort => 'አስተካክል';

  @override
  String get refresh => 'አድስ';

  @override
  String get updating => 'በማዘመን ላይ...';

  @override
  String get saving => 'በማስቀመጥ ላይ...';

  @override
  String get errorLoadingDashboard => 'ዳሽቦርዱን መጫን አልተሳካም';

  @override
  String get allProtectionsOn => 'ሁሉም ጥበቃዎች በርተዋል';

  @override
  String get familySafeNow => 'ቤተሰብዎ አሁን\nደህንነቱ የተጠበቀ ነው';

  @override
  String get protectedDevice => 'የተጠበቀ መሣሪያ';

  @override
  String get noChildrenConnectedYet => 'እስካሁን ምንም ልጅ አልተገናኘም';

  @override
  String get noChildrenDescription => 'ልጅዎን ለመጠበቅ የስልኩን QR ኮድ በመቃኘት ያገናኙ።';

  @override
  String get parentAccount => 'የወላጅ መለያ';

  @override
  String get protectedParentPortal => 'የተጠበቀ የወላጅ ፖርታል';

  @override
  String get settingsProfileSubtitle => 'ስም፣ ደህንነት፣ ገጽታ እና ቋንቋ ያርትዑ';

  @override
  String get settingsPairSubtitle => 'የልጅ ስልክ ለማዋቀር QR ኮድ ይፍጠሩ';

  @override
  String get settingsSwitchRoleSubtitle => 'በወላጅ እና በልጅ ሁነታ መካከል ይቀይሩ';

  @override
  String get settingsDevicePermissionsSubtitle =>
      'የስርዓት ክትትል እና የፍቃድ ሁኔታን ያረጋግጡ';

  @override
  String get darkNavyPalette => 'ጨለማ የባህር ኃይል ገጽታ';

  @override
  String get darkNavyDescription => 'በሁሉም ገጾች ላይ አንድ ወጥ የሆነ ጨለማ ገጽታ';

  @override
  String get lightThemeEnabled => 'የብርሃን ገጽታ ነቅቷል';

  @override
  String get pending => 'በመጠባበቅ ላይ';

  @override
  String get approved => 'የተፈቀደ';

  @override
  String get denied => 'የተከለከለ';

  @override
  String get all => 'ሁሉም';

  @override
  String get familyControls => 'የቤተሰብ ቁጥጥር';

  @override
  String get parentDashboard => 'የወላጅ ቁጥጥር ዳሽቦርድ';

  @override
  String get familyLocations => 'የቤተሰብ አቀማመጥ';

  @override
  String get liveGpsTracking => 'የቀጥታ GPS ክትትል';

  @override
  String get appRequests => 'የመተግበሪያ ጥያቄዎች';

  @override
  String get approveOrDenyRequests => 'የልጅ መዳረሻ ፍቀድ ወይም ከልክል';

  @override
  String get educationCenter => 'የትምህርት ማዕከል';

  @override
  String get manageLearningMaterials => 'የትምህርት ቁሳቁሶችን ይቆጣጠሩ እና ይከታተሉ';

  @override
  String get uploadMaterial => 'የትምህርት ቁሳቁስ ጫን';

  @override
  String get realTimeAlerts => 'የቀጥታ የልጆች ማስጠንቀቂያዎች';

  @override
  String get markAllAsRead => 'ሁሉንም እንደተነበበ ምልክት አድርግ';

  @override
  String get openNativeMaps => 'በካርታ ላይ ክፈት';

  @override
  String get aboutSmartGuard => 'ስለ Smart Guard';

  @override
  String get smartGuardDescription =>
      'FamilyGuard መሣሪያዎን ሚዛናዊ እና ደህንነቱ የተጠበቀ ያደርጋል';

  @override
  String get gotIt => 'ተረድቻለሁ!';

  @override
  String get familyGroup => 'የቤተሰብ ቡድን';

  @override
  String get familyGroupConnected => 'ከወላጆች ጋር ተገናኝቷል';

  @override
  String get familyGroupScanPrompt => 'ለማገናኘት የወላጅ QR ኮድ ይቃኙ';

  @override
  String get aboutSmartGuardSubtitle => 'ጤናማ የዲጂታል ገደቦች እርስዎን እንዴት እንደሚጠብቁ';

  @override
  String get noChildrenLinkedYet => 'እስካሁን የተገናኘ ልጅ የለም';

  @override
  String get noPendingRequests => 'በመጠባበቅ ላይ ያለ ጥያቄ የለም';

  @override
  String get noNotificationsYet => 'ምንም አዲስ ማሳወቂያ የለም';

  @override
  String get chat => 'ውይይት';

  @override
  String get conversations => 'ውይይቶች';

  @override
  String get noConversations => 'እስካሁን ውይይት የለም';

  @override
  String get noLinkedContacts => 'ለመወያየት የተገናኙ የቤተሰብ አባላት የሉም።';

  @override
  String get startConversation => 'ውይይት ይጀምሩ';

  @override
  String get noMessagesYet => 'እስካሁን መልዕክት የለም';

  @override
  String get typeMessage => 'መልዕክት ይጻፉ';

  @override
  String get sending => 'በመላክ ላይ...';

  @override
  String get sent => 'ተልኳል';

  @override
  String get read => 'ተነብቧል';

  @override
  String get unread => 'ያልተነበበ';

  @override
  String get loadingMessages => 'መልዕክቶችን በመጫን ላይ...';

  @override
  String get noInternetConnection => 'የኢንተርኔት ግንኙነት የለም';

  @override
  String get messageFailedToSend => 'መልዕክቱን መላክ አልተሳካም';

  @override
  String get retrySendMessage => 'መላክን እንደገና ይሞክሩ';

  @override
  String get today => 'ዛሬ';

  @override
  String get yesterday => 'ትናንት';

  @override
  String get chatPrivacyNotice =>
      'መልዕክቶች በዚህ ውይይት ከተገናኙ የቤተሰብ አባላት ጋር ብቻ ይጋራሉ።';

  @override
  String get chatListLoadError => 'ውይይቶችን መጫን አልተቻለም።';

  @override
  String get chatMessagesLoadError => 'መልዕክቶችን መጫን አልተቻለም።';

  @override
  String get chatSendError => 'ይህን መልዕክት መላክ አልተቻለም።';

  @override
  String get chatTryAgain => 'እንደገና ይሞክሩ';

  @override
  String get chatOpen => 'ውይይት ክፈት';

  @override
  String get chatLatestMessage => 'የቅርብ ጊዜ መልዕክት';

  @override
  String chatUnreadCount(int count) {
    return '$count ያልተነበቡ';
  }
}
