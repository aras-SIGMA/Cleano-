// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cleano — Smart Laundry POS';

  @override
  String get navHome => 'Home';

  @override
  String get navPos => 'New Order';

  @override
  String get navPosShort => 'Order';

  @override
  String get navOrders => 'Orders';

  @override
  String get navStore => 'Manage Store';

  @override
  String get navStoreShort => 'Store';

  @override
  String get navAccount => 'Account';

  @override
  String get navTracking => 'Track';

  @override
  String get navRewards => 'Rewards';

  @override
  String get logout => 'Log Out';

  @override
  String get logoutConfirmTitle => 'Confirm Log Out';

  @override
  String get logoutConfirmKasir =>
      'Are you sure you want to log out of the cashier account?';

  @override
  String get logoutConfirmPelanggan =>
      'Are you sure you want to log out of your customer account?';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Try Again';

  @override
  String get delete => 'Delete';

  @override
  String get add => 'Add';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get understood => 'Got It';

  @override
  String get systemError => 'A system error occurred. Please try again.';

  @override
  String get pointsUnit => 'Pts';

  @override
  String get languageSettingTitle => 'App Language';

  @override
  String get languageSettingSubtitle => 'Choose system display language';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String languageChanged(String language) {
    return 'App language changed to $language.';
  }

  @override
  String get splashSubtitle =>
      'Modern, fast, and reliable laundry management solution for cashiers and customers.';

  @override
  String get login => 'Login';

  @override
  String get signUp => 'Sign up';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginSubtitle =>
      'Sign in to your account to manage laundry orders and access exclusive rewards.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailRequired => 'Email is required.';

  @override
  String get emailInvalid => 'Invalid email format.';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRequired => 'Password is required.';

  @override
  String get passwordMin8 => 'Password must be at least 8 characters.';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get cashier => 'Cashier';

  @override
  String get customer => 'Customer';

  @override
  String get devOnlyNote => 'Development mode only';

  @override
  String get noAccountQuestion => 'Don\'t have an account? ';

  @override
  String get registerTitle => 'Register';

  @override
  String get registerSubtitle =>
      'Create a new account to start washing and earn member points.';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get fullNameRequired => 'Full name is required.';

  @override
  String get fullNameMin2 => 'Name must be at least 2 characters.';

  @override
  String get phoneLabel => 'Phone Number (WhatsApp)';

  @override
  String get phoneRequired => 'Phone number is required.';

  @override
  String get phoneDigitsRule => 'Phone number must be 8-20 digits.';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get confirmPasswordRequired => 'Password confirmation is required.';

  @override
  String get confirmPasswordMismatch => 'Password confirmation does not match.';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get signIn => 'Sign in';

  @override
  String get registerSuccessTitle => 'Registration Successful!';

  @override
  String get registerSuccessSubtitle =>
      'Your account is active. Here is your member code to earn promos & points:';

  @override
  String get startUsingCleano => 'Start Using Cleano';

  @override
  String get kasirProfileTitle => 'Cashier Account & Settings';

  @override
  String get pelangganProfileTitle => 'My Profile & Account';

  @override
  String get sectionAccountSecurity => 'ACCOUNT & SECURITY';

  @override
  String get sectionHardwarePos => 'POS HARDWARE & DEVICES';

  @override
  String get sectionSopSupport => 'SOP & SUPPORT';

  @override
  String get sectionSystemApp => 'SYSTEM & APPLICATION';

  @override
  String get sectionServicePrefs => 'SERVICE PREFERENCES';

  @override
  String get sectionHelpGuide => 'HELP & GUIDE';

  @override
  String get registeredEmail => 'Registered Email';

  @override
  String get changePassword => 'Change Password';

  @override
  String get updatePassword => 'Update Password';

  @override
  String get changePasswordSubtitleKasir =>
      'Update your cashier password regularly for security';

  @override
  String get changePasswordSubtitlePelanggan =>
      'Update your customer account password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get currentPasswordRequired => 'Enter current password';

  @override
  String get newPasswordMin8Label => 'New Password (Min. 8 Characters)';

  @override
  String get passwordMin8Short => 'Password must be at least 8 characters';

  @override
  String get passwordMax128 => 'Password must be at most 128 characters';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get passwordMismatch => 'Password confirmation does not match';

  @override
  String get passwordUpdated => 'Password updated successfully.';

  @override
  String get passwordUpdateFailed =>
      'Failed to update password. Please try again.';

  @override
  String get savePassword => 'Save Password';

  @override
  String get kasirCloseShiftLogout => 'End Shift & Log Out';

  @override
  String get pelangganLogoutBtn => 'Log Out of Account';

  @override
  String get staffRoleBadge => 'CASHIER STAFF';

  @override
  String get outletCenterName => 'Cleano Outlet 01 — Sukajadi Center';

  @override
  String get onlineBadge => 'ONLINE';

  @override
  String get shiftTitle => 'Cashier Shift';

  @override
  String get shiftMorningValue => 'Morning (08-16)';

  @override
  String get counterPosTitle => 'POS Counter';

  @override
  String get counterReadyValue => 'Ready to Serve';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncRealtimeValue => 'Realtime';

  @override
  String get whatsappNumber => 'WhatsApp Number';

  @override
  String get activeWhatsappNumber => 'Active WhatsApp Number';

  @override
  String get changePasswordSub => 'Change login password for account security';

  @override
  String get authPinTitle => 'Cashier Auth PIN';

  @override
  String get authPinSubtitle => 'Supervisor PIN for order cancellation';

  @override
  String get authPinInfo =>
      'Authorization PIN is configured by the outlet manager.';

  @override
  String get thermalPrinterTitle => 'Bluetooth Thermal Printer';

  @override
  String get printerConnected => 'Connected (ESC/POS 58mm)';

  @override
  String get printerDisconnected => 'Disconnected (Tap to scan)';

  @override
  String get testPrint => 'Test Print';

  @override
  String get soundNotifTitle => 'Order Sound Notification';

  @override
  String get soundNotifSubtitle => 'Ring bell when new queue orders arrive';

  @override
  String get posScannerTitle => 'POS Camera Scanner';

  @override
  String get posScannerSubtitle => 'Rear camera active (Auto-focus)';

  @override
  String get posScannerInfo =>
      'Camera barcode scanner is ready in the New Order menu.';

  @override
  String get sopTitle => 'Cashier & Relay SOP Guide';

  @override
  String get sopSubtitle => '4 standard service & machine workflow steps';

  @override
  String get supervisorTitle => 'Supervisor & Support Contacts';

  @override
  String get supervisorSubtitle =>
      'Outlet person-in-charge & tech team numbers';

  @override
  String get termsPrivacyTitle => 'Terms of Service & Privacy';

  @override
  String get termsPrivacySubtitle => 'Customer data protection & laundry rules';

  @override
  String get privacyTermsDialogTitle => 'Privacy & Terms';

  @override
  String get simReceiptTitle => 'POS Receipt Preview';

  @override
  String get sendToPrinter => 'Send to Printer';

  @override
  String get printSentMsg => 'Print command sent to Bluetooth printer (58mm).';

  @override
  String get digitalPassTitle => 'Digital Member Access Card';

  @override
  String get digitalPassSubtitle => 'Present at drop-off at any Cleano outlet';

  @override
  String get tapToShowQr => 'Tap to Show QR Code';

  @override
  String get openQrCard => 'Open QR Card';

  @override
  String get send => 'Share';

  @override
  String get digitalMemberCardTitle => 'Digital Member Card';

  @override
  String get shareModalTitle => 'Send Card to Courier / Family';

  @override
  String get shareModalSubtitle =>
      'Make it easy for others to drop off laundry on your behalf';

  @override
  String get shareModalBenefit =>
      'The cashier only needs your member code to record the order. Points and wash notifications will still go straight to your account!';

  @override
  String get shareWhatsappFormat => 'Copy WhatsApp / Chat Message Format';

  @override
  String get shareWhatsappSubtitle =>
      'Ready-to-send text template with name, member code, and cashier guide';

  @override
  String shareCodeOnly(String code) {
    return 'Copy Member Code Only ($code)';
  }

  @override
  String get shareCodeOnlySubtitle =>
      'Send a short unique code for the cashier to look up';

  @override
  String get shareQrScreenshot => 'Show QR for Screenshot';

  @override
  String get shareQrScreenshotSubtitle =>
      'Open full QR card to screenshot and send as an image';

  @override
  String get shareMessageCopied =>
      'Laundry drop-off message copied to clipboard!';

  @override
  String memberCodeCopied(String code) {
    return 'Member code $code copied!';
  }

  @override
  String get redeemRewardsLink => 'Redeem Rewards →';

  @override
  String get highestTierVip => 'Highest Tier (VIP)';

  @override
  String pointsToGold(int pts) {
    return '$pts pts to Gold';
  }

  @override
  String pointsToPlatinum(Object pts) {
    return '$pts pts to Platinum';
  }

  @override
  String get favOutletTitle => 'Primary Outlet';

  @override
  String get favOutletSubtitle =>
      'Cleano Outlet 01 — Sukajadi Center (Bandung)';

  @override
  String get favOutletInfo =>
      'Cleano Outlet 01 is your account\'s primary branch.';

  @override
  String get waNotifTitle => 'Laundry WhatsApp Notifications';

  @override
  String get waNotifSubtitle =>
      'Receive automatic WA messages when laundry is ready';

  @override
  String get csWhatsappTitle => 'WhatsApp Help Center';

  @override
  String get csWhatsappSubtitle =>
      'Contact Cleano Customer Care (0812-9988-7766)';

  @override
  String get csPhoneCopied => 'Cleano CS number copied!';

  @override
  String get pointsGuideTitle => 'Points & Rewards Guide';

  @override
  String get pointsGuideSubtitle =>
      'How to earn 2x points and redeem discount vouchers';

  @override
  String get privacyTitle => 'Terms & Privacy Policy';

  @override
  String get privacySubtitle => 'Data protection and laundry service terms';

  @override
  String get dashboardTitle => 'Cashier Dashboard';

  @override
  String get downloadRecap => 'Download Recap';

  @override
  String get periodToday => 'Today';

  @override
  String get period7Days => 'Last 7 Days';

  @override
  String get periodThisMonth => 'This Month';

  @override
  String get metricTodayRevenue => 'Today\'s Revenue';

  @override
  String get metricActiveOrders => 'Active Orders';

  @override
  String get metricReadyOrders => 'Ready for Pickup';

  @override
  String get metricAvailableMachines => 'Available Machines';

  @override
  String get readyShort => 'Ready';

  @override
  String get activeOrdersTitle => 'Active Orders';

  @override
  String get seeAll => 'See All >';

  @override
  String filterAllCount(int count) {
    return 'All ($count)';
  }

  @override
  String get filterWaitingMachine => 'Waiting Machine';

  @override
  String get filterWashing => 'Washing';

  @override
  String get noActiveOrdersInCategory =>
      'No active laundry orders in this category.';

  @override
  String get exportModalTitle => 'Export Report Summary';

  @override
  String get exportModalSubtitle => 'Download Cleano cashier operational recap';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String exportSuccess(String format) {
    return 'Report exported as $format successfully.';
  }

  @override
  String exportFailed(String err) {
    return 'Failed to export report: $err';
  }

  @override
  String get noRevenue7Days => 'No revenue data available for the last 7 days.';

  @override
  String get ordersTitle => 'Order List';

  @override
  String get searchOrdersHint => 'Search order code, name, or phone...';

  @override
  String get statusAll => 'All';

  @override
  String get statusQueue => 'Queued';

  @override
  String get statusWashing => 'Washing';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusDone => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get checkPayment => 'Check Pay';

  @override
  String get markReady => 'Mark Ready';

  @override
  String get completeOrder => 'Complete Order';

  @override
  String get cancelOrder => 'Cancel Order';

  @override
  String get paidBadge => 'PAID';

  @override
  String get unpaidBadge => 'UNPAID';

  @override
  String get posTitle => 'New Laundry Order';

  @override
  String get stepSelectCustomer => 'Select Customer';

  @override
  String get searchCustomerHint => 'Search MBR-XXXX or Phone...';

  @override
  String get scanQrMember => 'Scan Customer Member QR';

  @override
  String get stepServiceWeight => 'Service & Laundry Weight';

  @override
  String get laundryWeightKg => 'Laundry Weight (kg)';

  @override
  String get notesOptional => 'Special Notes (Optional)';

  @override
  String get stepVoucher => 'Discount Voucher';

  @override
  String get stepPayment => 'Payment Method';

  @override
  String get processTransaction => 'Process Transaction';

  @override
  String get orderSavedSuccess => 'Order Saved Successfully!';

  @override
  String get newLaundryBtn => 'New Order';

  @override
  String get changeCustomer => 'Change Customer';

  @override
  String get selectLaundryService => 'Select Laundry Service';

  @override
  String get takeClothingPhoto => 'Take Clothing Proof Photo';

  @override
  String get typeVoucherHint => 'Enter voucher code...';

  @override
  String get applyVoucher => 'Apply';

  @override
  String get manageStoreTitle => 'Manage Store';

  @override
  String get refreshData => 'Refresh Data';

  @override
  String get newServiceBtn => 'New Service';

  @override
  String get newMachineBtn => 'New Machine';

  @override
  String get newRewardBtn => 'New Voucher';

  @override
  String get addBtn => 'Add';

  @override
  String helloGreeting(String name) {
    return 'Hello, $name 👋';
  }

  @override
  String get pointsBalanceLabel => 'Points Balance';

  @override
  String get weeklyActivityTitle => 'Last 7 Days Activity';

  @override
  String get fromRecentHistory => 'from recent history';

  @override
  String get laundryCountLabel => 'Orders';

  @override
  String get totalWeightLabel => 'Total Weight';

  @override
  String get pointsEarnedLabel => 'Points Earned';

  @override
  String activeLaundryTab(int count) {
    return 'Active Orders ($count)';
  }

  @override
  String completedHistoryTab(int count) {
    return 'History ($count)';
  }

  @override
  String get noActiveLaundry => 'No laundry orders currently in progress.';

  @override
  String get noCompletedHistory => 'No completed laundry history yet.';

  @override
  String get dropoffPhotoTitle => 'Drop-Off Clothing Proof Photo';

  @override
  String get serviceLabel => 'Service';

  @override
  String get weightLabel => 'Laundry Weight';

  @override
  String get totalPaymentLabel => 'Total Payment';

  @override
  String get methodStatusLabel => 'Method / Status';

  @override
  String get rewardsTitle => 'Loyalty & Rewards';

  @override
  String get rewardsSubtitle => 'Collect Points & Claim Exciting Promos';

  @override
  String get myPointsBalance => 'MY POINTS BALANCE';

  @override
  String get highestTierLabel => 'Highest Membership Tier';

  @override
  String get bonus2xTitle => '2x Loyalty Points Bonus ⚡';

  @override
  String get bonus2xSubtitle =>
      'Automatically earn 2x points for orders ≥ 5 kg or Express services!';

  @override
  String catalogTab(int count) {
    return 'Rewards Catalog ($count)';
  }

  @override
  String myVouchersTab(int count) {
    return 'My Vouchers ($count)';
  }

  @override
  String get redeemPointsBtn => 'Redeem Points';

  @override
  String get insufficientPointsBtn => 'Not Enough Points';

  @override
  String get oneTimeUseBadge => '1x Use';

  @override
  String get copyCodeBtn => 'Copy Code';

  @override
  String get usedBadge => 'Already Used';

  @override
  String get changeProfilePhoto => 'Change Profile Photo';

  @override
  String get takeFromCamera => 'Take from Camera';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get avatarUpdated => 'Profile photo updated successfully.';

  @override
  String avatarUpdateFailed(String err) {
    return 'Failed to update profile photo: $err';
  }
}
