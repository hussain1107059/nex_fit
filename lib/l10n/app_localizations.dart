import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bs.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bs'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In bs, this message translates to:
  /// **'NexFit'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In bs, this message translates to:
  /// **'আপনার ফিটনেস যাত্রা, শুরু হোক আজ'**
  String get appTagline;

  /// No description provided for @commonContinue.
  ///
  /// In bs, this message translates to:
  /// **'চালিয়ে যান'**
  String get commonContinue;

  /// No description provided for @commonCancel.
  ///
  /// In bs, this message translates to:
  /// **'বাতিল'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In bs, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In bs, this message translates to:
  /// **'সংরক্ষণ করুন'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In bs, this message translates to:
  /// **'মুছে ফেলুন'**
  String get commonDelete;

  /// No description provided for @commonConfirm.
  ///
  /// In bs, this message translates to:
  /// **'নিশ্চিত করুন'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In bs, this message translates to:
  /// **'বন্ধ করুন'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In bs, this message translates to:
  /// **'পেছনে যান'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In bs, this message translates to:
  /// **'পরবর্তী'**
  String get commonNext;

  /// No description provided for @commonDone.
  ///
  /// In bs, this message translates to:
  /// **'সম্পন্ন'**
  String get commonDone;

  /// No description provided for @commonSkip.
  ///
  /// In bs, this message translates to:
  /// **'এড়িয়ে যান'**
  String get commonSkip;

  /// No description provided for @commonOk.
  ///
  /// In bs, this message translates to:
  /// **'ঠিক আছে'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In bs, this message translates to:
  /// **'হ্যাঁ'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In bs, this message translates to:
  /// **'না'**
  String get commonNo;

  /// No description provided for @commonLoading.
  ///
  /// In bs, this message translates to:
  /// **'লোড হচ্ছে...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In bs, this message translates to:
  /// **'একটি সমস্যা হয়েছে'**
  String get commonError;

  /// No description provided for @commonTryAgain.
  ///
  /// In bs, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get commonTryAgain;

  /// No description provided for @commonViewAll.
  ///
  /// In bs, this message translates to:
  /// **'সব দেখুন'**
  String get commonViewAll;

  /// No description provided for @commonSearch.
  ///
  /// In bs, this message translates to:
  /// **'খুঁজুন'**
  String get commonSearch;

  /// No description provided for @commonSettings.
  ///
  /// In bs, this message translates to:
  /// **'সেটিংস'**
  String get commonSettings;

  /// No description provided for @commonProfile.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল'**
  String get commonProfile;

  /// No description provided for @commonLanguage.
  ///
  /// In bs, this message translates to:
  /// **'ভাষা'**
  String get commonLanguage;

  /// No description provided for @commonTheme.
  ///
  /// In bs, this message translates to:
  /// **'থিম'**
  String get commonTheme;

  /// No description provided for @commonNotification.
  ///
  /// In bs, this message translates to:
  /// **'বিজ্ঞপ্তি'**
  String get commonNotification;

  /// No description provided for @commonEdit.
  ///
  /// In bs, this message translates to:
  /// **'সম্পাদনা করুন'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In bs, this message translates to:
  /// **'যোগ করুন'**
  String get commonAdd;

  /// No description provided for @commonToday.
  ///
  /// In bs, this message translates to:
  /// **'আজ'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In bs, this message translates to:
  /// **'গতকাল'**
  String get commonYesterday;

  /// No description provided for @commonWeek.
  ///
  /// In bs, this message translates to:
  /// **'সপ্তাহ'**
  String get commonWeek;

  /// No description provided for @commonMonth.
  ///
  /// In bs, this message translates to:
  /// **'মাস'**
  String get commonMonth;

  /// No description provided for @commonYear.
  ///
  /// In bs, this message translates to:
  /// **'বছর'**
  String get commonYear;

  /// No description provided for @tabHome.
  ///
  /// In bs, this message translates to:
  /// **'হোম'**
  String get tabHome;

  /// No description provided for @tabWorkout.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট'**
  String get tabWorkout;

  /// No description provided for @tabDiet.
  ///
  /// In bs, this message translates to:
  /// **'ডায়েট'**
  String get tabDiet;

  /// No description provided for @tabProgress.
  ///
  /// In bs, this message translates to:
  /// **'অগ্রগতি'**
  String get tabProgress;

  /// No description provided for @tabNutrition.
  ///
  /// In bs, this message translates to:
  /// **'পুষ্টি'**
  String get tabNutrition;

  /// No description provided for @tabProfile.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল'**
  String get tabProfile;

  /// No description provided for @moduleWorkoutSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'এখানে আপনার ওয়ার্কআউট পরিকল্পনা ও ট্র্যাক করুন।'**
  String get moduleWorkoutSubtitle;

  /// No description provided for @moduleProgressSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'এখানে আপনার অগ্রগতি ও পরিসংখ্যান দেখুন।'**
  String get moduleProgressSubtitle;

  /// No description provided for @moduleNutritionSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'এখানে আপনার খাবার ও পুষ্টি পরিচালনা করুন।'**
  String get moduleNutritionSubtitle;

  /// No description provided for @moduleProfileSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'এখানে আপনার অ্যাকাউন্ট ও সেটিংস থাকবে।'**
  String get moduleProfileSubtitle;

  /// No description provided for @emptyNoData.
  ///
  /// In bs, this message translates to:
  /// **'এখনও কোনো তথ্য নেই'**
  String get emptyNoData;

  /// No description provided for @emptyNoDataSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার প্রথম তথ্য যোগ করুন, এটি এখানে দেখা যাবে।'**
  String get emptyNoDataSubtitle;

  /// No description provided for @emptyNoResults.
  ///
  /// In bs, this message translates to:
  /// **'কোনো ফলাফল পাওয়া যায়নি'**
  String get emptyNoResults;

  /// No description provided for @emptyNoResultsSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'অন্য কিছু খুঁজে দেখুন।'**
  String get emptyNoResultsSubtitle;

  /// No description provided for @emptyNoInternet.
  ///
  /// In bs, this message translates to:
  /// **'ইন্টারনেট সংযোগ নেই'**
  String get emptyNoInternet;

  /// No description provided for @emptyNoInternetSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'সংযোগ ফিরে এলে আবার চেষ্টা করুন।'**
  String get emptyNoInternetSubtitle;

  /// No description provided for @errorSomethingWentWrong.
  ///
  /// In bs, this message translates to:
  /// **'কিছু একটা সমস্যা হয়েছে'**
  String get errorSomethingWentWrong;

  /// No description provided for @errorSomethingWentWrongSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'অপ্রত্যাশিত একটি ত্রুটি ঘটেছে। আবার চেষ্টা করুন।'**
  String get errorSomethingWentWrongSubtitle;

  /// No description provided for @errorNoInternet.
  ///
  /// In bs, this message translates to:
  /// **'ইন্টারনেট সংযোগ নেই'**
  String get errorNoInternet;

  /// No description provided for @errorNoInternetSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'অনুগ্রহ করে আপনার ইন্টারনেট সংযোগ পরীক্ষা করুন।'**
  String get errorNoInternetSubtitle;

  /// No description provided for @errorTimeout.
  ///
  /// In bs, this message translates to:
  /// **'সময় শেষ হয়ে গেছে'**
  String get errorTimeout;

  /// No description provided for @errorTimeoutSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'অনুরোধটি অনেক সময় নিয়েছে। আবার চেষ্টা করুন।'**
  String get errorTimeoutSubtitle;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In bs, this message translates to:
  /// **'অনুমতি নেই'**
  String get errorPermissionDenied;

  /// No description provided for @errorPermissionDeniedSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'এই কাজটি করার জন্য আপনার অনুমতি নেই।'**
  String get errorPermissionDeniedSubtitle;

  /// No description provided for @errorNetwork.
  ///
  /// In bs, this message translates to:
  /// **'নেটওয়ার্ক ত্রুটি'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In bs, this message translates to:
  /// **'সার্ভার ত্রুটি'**
  String get errorServer;

  /// No description provided for @errorServerSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'সার্ভার থেকে সাড়া পাওয়া যায়নি। কিছুক্ষণ পর আবার চেষ্টা করুন।'**
  String get errorServerSubtitle;

  /// No description provided for @errorDatabase.
  ///
  /// In bs, this message translates to:
  /// **'ডেটাবেস ত্রুটি'**
  String get errorDatabase;

  /// No description provided for @errorDatabaseSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'লোকাল ডেটাবেস থেকে তথ্য পড়া যাচ্ছে না।'**
  String get errorDatabaseSubtitle;

  /// No description provided for @errorUnknown.
  ///
  /// In bs, this message translates to:
  /// **'অজানা ত্রুটি'**
  String get errorUnknown;

  /// No description provided for @authSignInTitle.
  ///
  /// In bs, this message translates to:
  /// **'স্বাগতম ফিরে আসায়'**
  String get authSignInTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার অ্যাকাউন্টে প্রবেশ করুন'**
  String get authSignInSubtitle;

  /// No description provided for @authSignUpTitle.
  ///
  /// In bs, this message translates to:
  /// **'নতুন অ্যাকাউন্ট তৈরি করুন'**
  String get authSignUpTitle;

  /// No description provided for @authEmail.
  ///
  /// In bs, this message translates to:
  /// **'ইমেইল'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In bs, this message translates to:
  /// **'পাসওয়ার্ড'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In bs, this message translates to:
  /// **'পাসওয়ার্ড নিশ্চিত করুন'**
  String get authConfirmPassword;

  /// No description provided for @authSignIn.
  ///
  /// In bs, this message translates to:
  /// **'সাইন ইন'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In bs, this message translates to:
  /// **'সাইন আপ'**
  String get authSignUp;

  /// No description provided for @authSignOut.
  ///
  /// In bs, this message translates to:
  /// **'সাইন আউট'**
  String get authSignOut;

  /// No description provided for @authForgotPassword.
  ///
  /// In bs, this message translates to:
  /// **'পাসওয়ার্ড ভুলে গেছেন?'**
  String get authForgotPassword;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In bs, this message translates to:
  /// **'গুগল দিয়ে চালিয়ে যান'**
  String get authContinueWithGoogle;

  /// No description provided for @authEmailRequired.
  ///
  /// In bs, this message translates to:
  /// **'ইমেইল প্রয়োজন'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In bs, this message translates to:
  /// **'সঠিক ইমেইল ঠিকানা দিন'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In bs, this message translates to:
  /// **'পাসওয়ার্ড প্রয়োজন'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In bs, this message translates to:
  /// **'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In bs, this message translates to:
  /// **'পাসওয়ার্ড মিলছে না'**
  String get authPasswordMismatch;

  /// No description provided for @authName.
  ///
  /// In bs, this message translates to:
  /// **'নাম'**
  String get authName;

  /// No description provided for @authNameRequired.
  ///
  /// In bs, this message translates to:
  /// **'নাম প্রয়োজন'**
  String get authNameRequired;

  /// No description provided for @authUnavailable.
  ///
  /// In bs, this message translates to:
  /// **'অথেনটিকেশন এখন উপলব্ধ নয়। পরে আবার চেষ্টা করুন।'**
  String get authUnavailable;

  /// No description provided for @authCancelled.
  ///
  /// In bs, this message translates to:
  /// **'সাইন ইন বাতিল করা হয়েছে'**
  String get authCancelled;

  /// No description provided for @authGoogleSignInFailed.
  ///
  /// In bs, this message translates to:
  /// **'গুগল সাইন ইন ব্যর্থ হয়েছে'**
  String get authGoogleSignInFailed;

  /// No description provided for @authUserNotFound.
  ///
  /// In bs, this message translates to:
  /// **'এই ইমেইলের কোনো অ্যাকাউন্ট পাওয়া যায়নি'**
  String get authUserNotFound;

  /// No description provided for @authWrongPassword.
  ///
  /// In bs, this message translates to:
  /// **'ভুল পাসওয়ার্ড'**
  String get authWrongPassword;

  /// No description provided for @authEmailInUse.
  ///
  /// In bs, this message translates to:
  /// **'এই ইমেইলটি ইতিমধ্যে ব্যবহৃত হচ্ছে'**
  String get authEmailInUse;

  /// No description provided for @authUserDisabled.
  ///
  /// In bs, this message translates to:
  /// **'এই অ্যাকাউন্টটি নিষ্ক্রিয় করা হয়েছে'**
  String get authUserDisabled;

  /// No description provided for @authTooManyRequests.
  ///
  /// In bs, this message translates to:
  /// **'অনেকবার চেষ্টা করা হয়েছে। কিছুক্ষণ পর আবার চেষ্টা করুন।'**
  String get authTooManyRequests;

  /// No description provided for @authOperationNotAllowed.
  ///
  /// In bs, this message translates to:
  /// **'এই অপারেশনটি অনুমোদিত নয়'**
  String get authOperationNotAllowed;

  /// No description provided for @authAccountExistsWithDifferentCredential.
  ///
  /// In bs, this message translates to:
  /// **'এই ইমেইলে আগে থেকেই একটি অ্যাকাউন্ট আছে। সাইন ইন করে চেষ্টা করুন।'**
  String get authAccountExistsWithDifferentCredential;

  /// No description provided for @authGeneric.
  ///
  /// In bs, this message translates to:
  /// **'সাইন ইন করতে সমস্যা হয়েছে। আবার চেষ্টা করুন।'**
  String get authGeneric;

  /// No description provided for @authBusy.
  ///
  /// In bs, this message translates to:
  /// **'অনুগ্রহ করে অপেক্ষা করুন...'**
  String get authBusy;

  /// No description provided for @authOrContinueWith.
  ///
  /// In bs, this message translates to:
  /// **'অথবা এর মাধ্যমে চালিয়ে যান'**
  String get authOrContinueWith;

  /// No description provided for @authRememberMe.
  ///
  /// In bs, this message translates to:
  /// **'আমাকে মনে রাখুন'**
  String get authRememberMe;

  /// No description provided for @authNoAccount.
  ///
  /// In bs, this message translates to:
  /// **'অ্যাকাউন্ট নেই?'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In bs, this message translates to:
  /// **'ইতিমধ্যে অ্যাকাউন্ট আছে?'**
  String get authHaveAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In bs, this message translates to:
  /// **'অ্যাকাউন্ট তৈরি করুন'**
  String get authCreateAccount;

  /// No description provided for @authNameHint.
  ///
  /// In bs, this message translates to:
  /// **'আপনার পুরো নাম'**
  String get authNameHint;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'একটি নতুন অ্যাকাউন্ট তৈরি করুন এবং শুরু করুন'**
  String get authSignUpSubtitle;

  /// No description provided for @authPasswordWeak.
  ///
  /// In bs, this message translates to:
  /// **'পাসওয়ার্ডটি যথেষ্ট শক্তিশালী নয়। বড় হাতের, ছোট হাতের অক্ষর, সংখ্যা এবং চিহ্ন ব্যবহার করুন'**
  String get authPasswordWeak;

  /// No description provided for @authPasswordStrengthWeak.
  ///
  /// In bs, this message translates to:
  /// **'দুর্বল'**
  String get authPasswordStrengthWeak;

  /// No description provided for @authPasswordStrengthMedium.
  ///
  /// In bs, this message translates to:
  /// **'মাঝারি'**
  String get authPasswordStrengthMedium;

  /// No description provided for @authPasswordStrengthStrong.
  ///
  /// In bs, this message translates to:
  /// **'শক্তিশালী'**
  String get authPasswordStrengthStrong;

  /// No description provided for @authEmailVerificationTitle.
  ///
  /// In bs, this message translates to:
  /// **'ইমেইল নিশ্চিত করুন'**
  String get authEmailVerificationTitle;

  /// No description provided for @authEmailVerificationSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'চালিয়ে যাওয়ার আগে আপনার ইমেইল ঠিকানা নিশ্চিত করুন'**
  String get authEmailVerificationSubtitle;

  /// No description provided for @authEmailVerificationSentTo.
  ///
  /// In bs, this message translates to:
  /// **'আমরা একটি নিশ্চিতকরণ লিংক পাঠিয়েছি'**
  String get authEmailVerificationSentTo;

  /// No description provided for @authEmailNotVerified.
  ///
  /// In bs, this message translates to:
  /// **'ইমেইল যাচাইকৃত নয়'**
  String get authEmailNotVerified;

  /// No description provided for @authResendEmail.
  ///
  /// In bs, this message translates to:
  /// **'আবার নিশ্চিতকরণ ইমেইল পাঠান'**
  String get authResendEmail;

  /// No description provided for @authRefreshStatus.
  ///
  /// In bs, this message translates to:
  /// **'যাচাই করেছি, স্ট্যাটাস রিফ্রেশ করুন'**
  String get authRefreshStatus;

  /// No description provided for @authVerificationSent.
  ///
  /// In bs, this message translates to:
  /// **'নিশ্চিতকরণ ইমেইল পাঠানো হয়েছে'**
  String get authVerificationSent;

  /// No description provided for @authVerificationNotYet.
  ///
  /// In bs, this message translates to:
  /// **'আপনার ইমেইল এখনও নিশ্চিত হয়নি। আগে ইনবক্সের লিংকে ক্লিক করুন'**
  String get authVerificationNotYet;

  /// No description provided for @authEmailVerified.
  ///
  /// In bs, this message translates to:
  /// **'ইমেইল যাচাইকৃত'**
  String get authEmailVerified;

  /// No description provided for @authEmailVerificationFailed.
  ///
  /// In bs, this message translates to:
  /// **'নিশ্চিতকরণ ইমেইল পাঠানো যায়নি'**
  String get authEmailVerificationFailed;

  /// No description provided for @authAccountCreated.
  ///
  /// In bs, this message translates to:
  /// **'অ্যাকাউন্ট তৈরি হয়েছে!'**
  String get authAccountCreated;

  /// No description provided for @authAccountCreatedSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার অ্যাকাউন্ট প্রস্তুত। আমরা আপনার ইমেইলে একটি নিশ্চিতকরণ লিংক পাঠিয়েছি'**
  String get authAccountCreatedSubtitle;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In bs, this message translates to:
  /// **'পাসওয়ার্ড ভুলে গেছেন'**
  String get authForgotPasswordTitle;

  /// No description provided for @authForgotPasswordSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার ইমেইল দিন, আমরা একটি রিসেট লিংক পাঠাব'**
  String get authForgotPasswordSubtitle;

  /// No description provided for @authSendResetLink.
  ///
  /// In bs, this message translates to:
  /// **'রিসেট লিংক পাঠান'**
  String get authSendResetLink;

  /// No description provided for @authResetLinkSent.
  ///
  /// In bs, this message translates to:
  /// **'রিসেট লিংক পাঠানো হয়েছে!'**
  String get authResetLinkSent;

  /// No description provided for @authResetLinkSentSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার ইনবক্স বা স্প্যাম ফোল্ডার দেখুন এবং লিংকটি অনুসরণ করুন'**
  String get authResetLinkSentSubtitle;

  /// No description provided for @authBackToLogin.
  ///
  /// In bs, this message translates to:
  /// **'সাইন ইন পেজে ফিরে যান'**
  String get authBackToLogin;

  /// No description provided for @authSignOutConfirmTitle.
  ///
  /// In bs, this message translates to:
  /// **'সাইন আউট করবেন?'**
  String get authSignOutConfirmTitle;

  /// No description provided for @authSignOutConfirmMessage.
  ///
  /// In bs, this message translates to:
  /// **'আপনি কি নিশ্চিত যে সাইন আউট করতে চান?'**
  String get authSignOutConfirmMessage;

  /// No description provided for @dashboardTemporaryTitle.
  ///
  /// In bs, this message translates to:
  /// **'অস্থায়ী ড্যাশবোর্ড'**
  String get dashboardTemporaryTitle;

  /// No description provided for @dashboardTemporarySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'এটি একটি অস্থায়ী স্ক্রিন। আসল ড্যাশবোর্ড পরবর্তী ধাপে তৈরি হবে'**
  String get dashboardTemporarySubtitle;

  /// No description provided for @dashboardMemberSince.
  ///
  /// In bs, this message translates to:
  /// **'সদস্য সূচনাকাল'**
  String get dashboardMemberSince;

  /// No description provided for @dashboardLastLogin.
  ///
  /// In bs, this message translates to:
  /// **'শেষ লগইন'**
  String get dashboardLastLogin;

  /// No description provided for @connectivityOnline.
  ///
  /// In bs, this message translates to:
  /// **'আপনি অনলাইনে আছেন'**
  String get connectivityOnline;

  /// No description provided for @connectivityOffline.
  ///
  /// In bs, this message translates to:
  /// **'আপনি অফলাইনে আছেন'**
  String get connectivityOffline;

  /// No description provided for @connectivityBackOnline.
  ///
  /// In bs, this message translates to:
  /// **'সংযোগ ফিরে এসেছে'**
  String get connectivityBackOnline;

  /// No description provided for @themeSystem.
  ///
  /// In bs, this message translates to:
  /// **'সিস্টেম'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In bs, this message translates to:
  /// **'লাইট'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In bs, this message translates to:
  /// **'ডার্ক'**
  String get themeDark;

  /// No description provided for @splashLoading.
  ///
  /// In bs, this message translates to:
  /// **'NexFit প্রস্তুত হচ্ছে...'**
  String get splashLoading;

  /// No description provided for @backupTitle.
  ///
  /// In bs, this message translates to:
  /// **'ব্যাকআপ ও রিস্টোর'**
  String get backupTitle;

  /// No description provided for @backupLastBackup.
  ///
  /// In bs, this message translates to:
  /// **'শেষ ব্যাকআপ'**
  String get backupLastBackup;

  /// No description provided for @backupNever.
  ///
  /// In bs, this message translates to:
  /// **'কখনো নয়'**
  String get backupNever;

  /// No description provided for @backupUploading.
  ///
  /// In bs, this message translates to:
  /// **'ব্যাকআপ আপলোড হচ্ছে...'**
  String get backupUploading;

  /// No description provided for @backupRestoring.
  ///
  /// In bs, this message translates to:
  /// **'রিস্টোর হচ্ছে...'**
  String get backupRestoring;

  /// No description provided for @backupSuccess.
  ///
  /// In bs, this message translates to:
  /// **'ব্যাকআপ সফল হয়েছে'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In bs, this message translates to:
  /// **'ব্যাকআপ ব্যর্থ হয়েছে'**
  String get backupFailed;

  /// No description provided for @backupDriveDisconnected.
  ///
  /// In bs, this message translates to:
  /// **'গুগল ড্রাইভ সংযুক্ত নয়'**
  String get backupDriveDisconnected;

  /// No description provided for @backupNotFound.
  ///
  /// In bs, this message translates to:
  /// **'ব্যাকআপ পাওয়া যায়নি'**
  String get backupNotFound;

  /// No description provided for @backupCorrupted.
  ///
  /// In bs, this message translates to:
  /// **'ব্যাকআপ ফাইলটি ক্ষতিগ্রস্ত'**
  String get backupCorrupted;

  /// No description provided for @dashboardGreetingMorning.
  ///
  /// In bs, this message translates to:
  /// **'শুভ সকাল'**
  String get dashboardGreetingMorning;

  /// No description provided for @dashboardGreetingAfternoon.
  ///
  /// In bs, this message translates to:
  /// **'শুভ অপরাহ্ন'**
  String get dashboardGreetingAfternoon;

  /// No description provided for @dashboardGreetingEvening.
  ///
  /// In bs, this message translates to:
  /// **'শুভ সন্ধ্যা'**
  String get dashboardGreetingEvening;

  /// No description provided for @dashboardTodayOverview.
  ///
  /// In bs, this message translates to:
  /// **'আজকের সারসংক্ষেপ'**
  String get dashboardTodayOverview;

  /// No description provided for @dashboardCaloriesBurned.
  ///
  /// In bs, this message translates to:
  /// **'ক্যালরি পুড়েছে'**
  String get dashboardCaloriesBurned;

  /// No description provided for @dashboardWater.
  ///
  /// In bs, this message translates to:
  /// **'পানি'**
  String get dashboardWater;

  /// No description provided for @dashboardSteps.
  ///
  /// In bs, this message translates to:
  /// **'পদক্ষেপ'**
  String get dashboardSteps;

  /// No description provided for @dashboardWeight.
  ///
  /// In bs, this message translates to:
  /// **'ওজন'**
  String get dashboardWeight;

  /// No description provided for @dashboardBmi.
  ///
  /// In bs, this message translates to:
  /// **'বিএমআই'**
  String get dashboardBmi;

  /// No description provided for @dashboardStreak.
  ///
  /// In bs, this message translates to:
  /// **'ধারাবাহিকতা'**
  String get dashboardStreak;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In bs, this message translates to:
  /// **'দ্রুত কর্ম'**
  String get dashboardQuickActions;

  /// No description provided for @dashboardStartWorkout.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট শুরু'**
  String get dashboardStartWorkout;

  /// No description provided for @dashboardLogWater.
  ///
  /// In bs, this message translates to:
  /// **'পানি যোগ করুন'**
  String get dashboardLogWater;

  /// No description provided for @dashboardAddMeal.
  ///
  /// In bs, this message translates to:
  /// **'খাবার যোগ করুন'**
  String get dashboardAddMeal;

  /// No description provided for @dashboardLogWeight.
  ///
  /// In bs, this message translates to:
  /// **'ওজন যোগ করুন'**
  String get dashboardLogWeight;

  /// No description provided for @dashboardBmiCalculator.
  ///
  /// In bs, this message translates to:
  /// **'বিএমআই হিসাব'**
  String get dashboardBmiCalculator;

  /// No description provided for @dashboardSleepTracker.
  ///
  /// In bs, this message translates to:
  /// **'ঘুম ট্র্যাকার'**
  String get dashboardSleepTracker;

  /// No description provided for @dashboardTodaysGoal.
  ///
  /// In bs, this message translates to:
  /// **'আজকের লক্ষ্য'**
  String get dashboardTodaysGoal;

  /// No description provided for @dashboardWorkoutMinutes.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট (মিনিট)'**
  String get dashboardWorkoutMinutes;

  /// No description provided for @dashboardCalories.
  ///
  /// In bs, this message translates to:
  /// **'ক্যালরি'**
  String get dashboardCalories;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In bs, this message translates to:
  /// **'সাম্প্রতিক কার্যকলাপ'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardNoActivity.
  ///
  /// In bs, this message translates to:
  /// **'এখনো কোনো কার্যকলাপ নেই'**
  String get dashboardNoActivity;

  /// No description provided for @dashboardNoActivitySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার কার্যকলাপ এখানে দেখা যাবে।'**
  String get dashboardNoActivitySubtitle;

  /// No description provided for @dashboardNoWorkoutYet.
  ///
  /// In bs, this message translates to:
  /// **'কোনো ওয়ার্কআউট নেই'**
  String get dashboardNoWorkoutYet;

  /// No description provided for @dashboardNoWorkoutYetSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার প্রথম ওয়ার্কআউট শুরু করুন এবং আজই শক্তি তৈরি করুন!'**
  String get dashboardNoWorkoutYetSubtitle;

  /// No description provided for @dashboardFirstWorkout.
  ///
  /// In bs, this message translates to:
  /// **'প্রথম ওয়ার্কআউট'**
  String get dashboardFirstWorkout;

  /// No description provided for @dashboardNoWeightYet.
  ///
  /// In bs, this message translates to:
  /// **'ওজন যোগ করা হয়নি'**
  String get dashboardNoWeightYet;

  /// No description provided for @dashboardNoWeightYetSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার অগ্রগতি ট্র্যাক করতে আজই ওজন যোগ করুন।'**
  String get dashboardNoWeightYetSubtitle;

  /// No description provided for @dashboardNoBadgeYet.
  ///
  /// In bs, this message translates to:
  /// **'এখনো কোনো ব্যাজ নেই'**
  String get dashboardNoBadgeYet;

  /// No description provided for @dashboardMotivation.
  ///
  /// In bs, this message translates to:
  /// **'অনুপ্রেরণা'**
  String get dashboardMotivation;

  /// No description provided for @dashboardAchievements.
  ///
  /// In bs, this message translates to:
  /// **'অর্জন'**
  String get dashboardAchievements;

  /// No description provided for @dashboardCurrentStreak.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান ধারা'**
  String get dashboardCurrentStreak;

  /// No description provided for @dashboardDays.
  ///
  /// In bs, this message translates to:
  /// **'দিন'**
  String get dashboardDays;

  /// No description provided for @dashboardUpcomingReminders.
  ///
  /// In bs, this message translates to:
  /// **'আজকের রিমাইন্ডার'**
  String get dashboardUpcomingReminders;

  /// No description provided for @dashboardNoReminders.
  ///
  /// In bs, this message translates to:
  /// **'আজ কোনো রিমাইন্ডার নেই'**
  String get dashboardNoReminders;

  /// No description provided for @dashboardNoRemindersSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'নতুন রিমাইন্ডার যোগ করতে সেটিংস দেখুন।'**
  String get dashboardNoRemindersSubtitle;

  /// No description provided for @dashboardWeeklyStats.
  ///
  /// In bs, this message translates to:
  /// **'সাপ্তাহিক পরিসংখ্যান'**
  String get dashboardWeeklyStats;

  /// No description provided for @dashboardNoDataWeek.
  ///
  /// In bs, this message translates to:
  /// **'এই সপ্তাহে কোনো তথ্য নেই'**
  String get dashboardNoDataWeek;

  /// No description provided for @dashboardNoWeightData.
  ///
  /// In bs, this message translates to:
  /// **'এই সপ্তাহে কোনো ওজন নেই'**
  String get dashboardNoWeightData;

  /// No description provided for @dashboardGoalNotSet.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য নির্ধারণ করা হয়নি'**
  String get dashboardGoalNotSet;

  /// No description provided for @dashboardComingSoon.
  ///
  /// In bs, this message translates to:
  /// **'এই মডিউলটি শীঘ্রই আসছে'**
  String get dashboardComingSoon;

  /// No description provided for @dashboardLogWaterTitle.
  ///
  /// In bs, this message translates to:
  /// **'পানি যোগ করুন'**
  String get dashboardLogWaterTitle;

  /// No description provided for @dashboardLogWaterHint.
  ///
  /// In bs, this message translates to:
  /// **'পরিমাণ নির্বাচন করুন (মিলি)'**
  String get dashboardLogWaterHint;

  /// No description provided for @dashboardLogWaterSuccess.
  ///
  /// In bs, this message translates to:
  /// **'পানি যোগ করা হয়েছে'**
  String get dashboardLogWaterSuccess;

  /// No description provided for @dashboardLogWeightTitle.
  ///
  /// In bs, this message translates to:
  /// **'ওজন যোগ করুন'**
  String get dashboardLogWeightTitle;

  /// No description provided for @dashboardLogWeightHint.
  ///
  /// In bs, this message translates to:
  /// **'ওজন (কেজি)'**
  String get dashboardLogWeightHint;

  /// No description provided for @dashboardLogWeightSuccess.
  ///
  /// In bs, this message translates to:
  /// **'ওজন যোগ করা হয়েছে'**
  String get dashboardLogWeightSuccess;

  /// No description provided for @dashboardBmiTitle.
  ///
  /// In bs, this message translates to:
  /// **'বিএমআই ক্যালকুলেটর'**
  String get dashboardBmiTitle;

  /// No description provided for @dashboardHeightCm.
  ///
  /// In bs, this message translates to:
  /// **'উচ্চতা (সেমি)'**
  String get dashboardHeightCm;

  /// No description provided for @dashboardWeightKg.
  ///
  /// In bs, this message translates to:
  /// **'ওজন (কেজি)'**
  String get dashboardWeightKg;

  /// No description provided for @dashboardBmiResult.
  ///
  /// In bs, this message translates to:
  /// **'বিএমআই'**
  String get dashboardBmiResult;

  /// No description provided for @dashboardBmiSaved.
  ///
  /// In bs, this message translates to:
  /// **'বিএমআই সংরক্ষিত হয়েছে'**
  String get dashboardBmiSaved;

  /// No description provided for @dashboardSearchHint.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট, খাবার, ব্যায়াম খুঁজুন...'**
  String get dashboardSearchHint;

  /// No description provided for @dashboardSearchWorkouts.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট'**
  String get dashboardSearchWorkouts;

  /// No description provided for @dashboardSearchExercises.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম'**
  String get dashboardSearchExercises;

  /// No description provided for @dashboardSearchFoods.
  ///
  /// In bs, this message translates to:
  /// **'খাবার'**
  String get dashboardSearchFoods;

  /// No description provided for @dashboardSearchMeals.
  ///
  /// In bs, this message translates to:
  /// **'খাবার (মিল)'**
  String get dashboardSearchMeals;

  /// No description provided for @dashboardLoadError.
  ///
  /// In bs, this message translates to:
  /// **'ড্যাশবোর্ড লোড করা যায়নি'**
  String get dashboardLoadError;

  /// No description provided for @dashboardActivityWorkout.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট'**
  String get dashboardActivityWorkout;

  /// No description provided for @dashboardActivityWater.
  ///
  /// In bs, this message translates to:
  /// **'পানি'**
  String get dashboardActivityWater;

  /// No description provided for @dashboardActivityMeal.
  ///
  /// In bs, this message translates to:
  /// **'খাবার'**
  String get dashboardActivityMeal;

  /// No description provided for @dashboardActivityWeight.
  ///
  /// In bs, this message translates to:
  /// **'ওজন'**
  String get dashboardActivityWeight;

  /// No description provided for @dashboardActivitySleep.
  ///
  /// In bs, this message translates to:
  /// **'ঘুম'**
  String get dashboardActivitySleep;

  /// No description provided for @dashboardMinutesShort.
  ///
  /// In bs, this message translates to:
  /// **'মিনিট'**
  String get dashboardMinutesShort;

  /// No description provided for @dashboardHoursShort.
  ///
  /// In bs, this message translates to:
  /// **'ঘণ্টা'**
  String get dashboardHoursShort;

  /// No description provided for @dashboardMlUnit.
  ///
  /// In bs, this message translates to:
  /// **'মিলি'**
  String get dashboardMlUnit;

  /// No description provided for @dashboardKgUnit.
  ///
  /// In bs, this message translates to:
  /// **'কেজি'**
  String get dashboardKgUnit;

  /// No description provided for @dashboardKcalUnit.
  ///
  /// In bs, this message translates to:
  /// **'কিলোক্যালরি'**
  String get dashboardKcalUnit;

  /// No description provided for @dashboardEarnedOn.
  ///
  /// In bs, this message translates to:
  /// **'অর্জিত'**
  String get dashboardEarnedOn;

  /// No description provided for @bmiUnderweight.
  ///
  /// In bs, this message translates to:
  /// **'ওজনে কম'**
  String get bmiUnderweight;

  /// No description provided for @bmiNormal.
  ///
  /// In bs, this message translates to:
  /// **'স্বাভাবিক'**
  String get bmiNormal;

  /// No description provided for @bmiOverweight.
  ///
  /// In bs, this message translates to:
  /// **'ওজন বেশি'**
  String get bmiOverweight;

  /// No description provided for @bmiObese.
  ///
  /// In bs, this message translates to:
  /// **'স্থূলকায়'**
  String get bmiObese;

  /// No description provided for @dialogConfirmTitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনি কি নিশ্চিত?'**
  String get dialogConfirmTitle;

  /// No description provided for @dialogExitApp.
  ///
  /// In bs, this message translates to:
  /// **'আপনি কি অ্যাপটি ছেড়ে যেতে চান?'**
  String get dialogExitApp;

  /// No description provided for @dialogDiscardChanges.
  ///
  /// In bs, this message translates to:
  /// **'আপনি কি পরিবর্তনগুলো বাতিল করতে চান?'**
  String get dialogDiscardChanges;

  /// No description provided for @exitAppHint.
  ///
  /// In bs, this message translates to:
  /// **'বের হতে আবার পেছনে যান'**
  String get exitAppHint;

  /// No description provided for @formFieldRequired.
  ///
  /// In bs, this message translates to:
  /// **'এই ঘরটি প্রয়োজন'**
  String get formFieldRequired;

  /// No description provided for @formFieldTooShort.
  ///
  /// In bs, this message translates to:
  /// **'মানটি খুব ছোট'**
  String get formFieldTooShort;

  /// No description provided for @formFieldTooLong.
  ///
  /// In bs, this message translates to:
  /// **'মানটি খুব বড়'**
  String get formFieldTooLong;

  /// No description provided for @formFieldInvalid.
  ///
  /// In bs, this message translates to:
  /// **'মানটি সঠিক নয়'**
  String get formFieldInvalid;

  /// No description provided for @profileTitle.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল'**
  String get profileTitle;

  /// No description provided for @profileMemberSince.
  ///
  /// In bs, this message translates to:
  /// **'সদস্য হিসেবে যুক্ত'**
  String get profileMemberSince;

  /// No description provided for @profileEditProfile.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল সম্পাদনা'**
  String get profileEditProfile;

  /// No description provided for @profileCompleteProfile.
  ///
  /// In bs, this message translates to:
  /// **'আপনার প্রোফাইল সম্পূর্ণ করুন'**
  String get profileCompleteProfile;

  /// No description provided for @profileCompleteProfileSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'শারীরিক তথ্য যোগ করে BMI, BMR ও দৈনিক লক্ষ্যমাত্রা আনলক করুন।'**
  String get profileCompleteProfileSubtitle;

  /// No description provided for @profilePhysicalInfo.
  ///
  /// In bs, this message translates to:
  /// **'শারীরিক তথ্য'**
  String get profilePhysicalInfo;

  /// No description provided for @profileAge.
  ///
  /// In bs, this message translates to:
  /// **'বয়স'**
  String get profileAge;

  /// No description provided for @profileYears.
  ///
  /// In bs, this message translates to:
  /// **'বছর'**
  String get profileYears;

  /// No description provided for @profileGender.
  ///
  /// In bs, this message translates to:
  /// **'লিঙ্গ'**
  String get profileGender;

  /// No description provided for @profileHeight.
  ///
  /// In bs, this message translates to:
  /// **'উচ্চতা'**
  String get profileHeight;

  /// No description provided for @profileCurrentWeight.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান ওজন'**
  String get profileCurrentWeight;

  /// No description provided for @profileTargetWeight.
  ///
  /// In bs, this message translates to:
  /// **'টার্গেট ওজন'**
  String get profileTargetWeight;

  /// No description provided for @profileFitnessGoal.
  ///
  /// In bs, this message translates to:
  /// **'ফিটনেস লক্ষ্য'**
  String get profileFitnessGoal;

  /// No description provided for @profileActivityLevel.
  ///
  /// In bs, this message translates to:
  /// **'কর্মক্ষমতার মাত্রা'**
  String get profileActivityLevel;

  /// No description provided for @profileBmi.
  ///
  /// In bs, this message translates to:
  /// **'BMI'**
  String get profileBmi;

  /// No description provided for @profileBmiValue.
  ///
  /// In bs, this message translates to:
  /// **'আপনার BMI'**
  String get profileBmiValue;

  /// No description provided for @profileBmiCategory.
  ///
  /// In bs, this message translates to:
  /// **'শ্রেণি'**
  String get profileBmiCategory;

  /// No description provided for @profileHealthyRange.
  ///
  /// In bs, this message translates to:
  /// **'সুস্থ পরিসর'**
  String get profileHealthyRange;

  /// No description provided for @profileSuggestion.
  ///
  /// In bs, this message translates to:
  /// **'পরামর্শ'**
  String get profileSuggestion;

  /// No description provided for @profileBmr.
  ///
  /// In bs, this message translates to:
  /// **'BMR'**
  String get profileBmr;

  /// No description provided for @profileDailyCalories.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক ক্যালোরি'**
  String get profileDailyCalories;

  /// No description provided for @profileDailyCaloriesTarget.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক ক্যালোরি লক্ষ্যমাত্রা'**
  String get profileDailyCaloriesTarget;

  /// No description provided for @profileDailyWaterTarget.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক পানি লক্ষ্যমাত্রা'**
  String get profileDailyWaterTarget;

  /// No description provided for @profileDailyStepTarget.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক পদক্ষেপ লক্ষ্যমাত্রা'**
  String get profileDailyStepTarget;

  /// No description provided for @profileDailyTargets.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক লক্ষ্যমাত্রা'**
  String get profileDailyTargets;

  /// No description provided for @profileStatistics.
  ///
  /// In bs, this message translates to:
  /// **'পরিসংখ্যান'**
  String get profileStatistics;

  /// No description provided for @profileTotalWorkouts.
  ///
  /// In bs, this message translates to:
  /// **'মোট ওয়ার্কআউট'**
  String get profileTotalWorkouts;

  /// No description provided for @profileCurrentStreak.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান ধারা'**
  String get profileCurrentStreak;

  /// No description provided for @profileLongestStreak.
  ///
  /// In bs, this message translates to:
  /// **'সর্বোচ্চ ধারা'**
  String get profileLongestStreak;

  /// No description provided for @profileCaloriesBurned.
  ///
  /// In bs, this message translates to:
  /// **'পোড়া ক্যালোরি'**
  String get profileCaloriesBurned;

  /// No description provided for @profileWaterIntake.
  ///
  /// In bs, this message translates to:
  /// **'পানি গ্রহণ'**
  String get profileWaterIntake;

  /// No description provided for @profileWeightLost.
  ///
  /// In bs, this message translates to:
  /// **'ওজন হ্রাস'**
  String get profileWeightLost;

  /// No description provided for @profileDays.
  ///
  /// In bs, this message translates to:
  /// **'দিন'**
  String get profileDays;

  /// No description provided for @profileNotSet.
  ///
  /// In bs, this message translates to:
  /// **'নির্ধারিত নয়'**
  String get profileNotSet;

  /// No description provided for @profileIncomplete.
  ///
  /// In bs, this message translates to:
  /// **'এটি দেখতে প্রোফাইল সম্পূর্ণ করুন'**
  String get profileIncomplete;

  /// No description provided for @settingsDarkMode.
  ///
  /// In bs, this message translates to:
  /// **'ডার্ক মোড'**
  String get settingsDarkMode;

  /// No description provided for @settingsLanguage.
  ///
  /// In bs, this message translates to:
  /// **'ভাষা'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In bs, this message translates to:
  /// **'বিজ্ঞপ্তি'**
  String get settingsNotifications;

  /// No description provided for @settingsBackupRestore.
  ///
  /// In bs, this message translates to:
  /// **'ব্যাকআপ ও রিস্টোর'**
  String get settingsBackupRestore;

  /// No description provided for @settingsAbout.
  ///
  /// In bs, this message translates to:
  /// **'সম্পর্কে'**
  String get settingsAbout;

  /// No description provided for @settingsLogout.
  ///
  /// In bs, this message translates to:
  /// **'লগ আউট'**
  String get settingsLogout;

  /// No description provided for @settingsComingSoon.
  ///
  /// In bs, this message translates to:
  /// **'এই ফিচারটি শীঘ্রই আসছে'**
  String get settingsComingSoon;

  /// No description provided for @settingsLastBackup.
  ///
  /// In bs, this message translates to:
  /// **'সর্বশেষ ব্যাকআপ'**
  String get settingsLastBackup;

  /// No description provided for @settingsNever.
  ///
  /// In bs, this message translates to:
  /// **'কখনোই নয়'**
  String get settingsNever;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In bs, this message translates to:
  /// **'NexFit সম্পর্কে'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutMessage.
  ///
  /// In bs, this message translates to:
  /// **'NexFit একটি প্রিমিয়াম, অফলাইন-প্রথম ফিটনেস সহচর যা আপনার ওয়ার্কআউট, পুষ্টি, শারীরিক পরিমাপ ও দৈনিক অগ্রগতি ট্র্যাক করে।'**
  String get settingsAboutMessage;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In bs, this message translates to:
  /// **'সংস্করণ'**
  String get settingsAboutVersion;

  /// No description provided for @editProfileTitle.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল সম্পাদনা'**
  String get editProfileTitle;

  /// No description provided for @editName.
  ///
  /// In bs, this message translates to:
  /// **'নাম'**
  String get editName;

  /// No description provided for @editNameHint.
  ///
  /// In bs, this message translates to:
  /// **'আপনার পূর্ণ নাম'**
  String get editNameHint;

  /// No description provided for @editDateOfBirth.
  ///
  /// In bs, this message translates to:
  /// **'জন্ম তারিখ'**
  String get editDateOfBirth;

  /// No description provided for @editCountry.
  ///
  /// In bs, this message translates to:
  /// **'দেশ'**
  String get editCountry;

  /// No description provided for @editCountryHint.
  ///
  /// In bs, this message translates to:
  /// **'আপনার দেশ'**
  String get editCountryHint;

  /// No description provided for @editLanguage.
  ///
  /// In bs, this message translates to:
  /// **'ভাষা'**
  String get editLanguage;

  /// No description provided for @editLanguageBangla.
  ///
  /// In bs, this message translates to:
  /// **'বাংলা'**
  String get editLanguageBangla;

  /// No description provided for @editLanguageEnglish.
  ///
  /// In bs, this message translates to:
  /// **'ইংরেজি'**
  String get editLanguageEnglish;

  /// No description provided for @editHeightCm.
  ///
  /// In bs, this message translates to:
  /// **'উচ্চতা (সেমি)'**
  String get editHeightCm;

  /// No description provided for @editWeightKg.
  ///
  /// In bs, this message translates to:
  /// **'ওজন (কেজি)'**
  String get editWeightKg;

  /// No description provided for @editTargetWeightKg.
  ///
  /// In bs, this message translates to:
  /// **'টার্গেট ওজন (কেজি)'**
  String get editTargetWeightKg;

  /// No description provided for @editProfilePhoto.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল ছবি'**
  String get editProfilePhoto;

  /// No description provided for @editChangePhoto.
  ///
  /// In bs, this message translates to:
  /// **'ছবি পরিবর্তন করুন'**
  String get editChangePhoto;

  /// No description provided for @editTakePhoto.
  ///
  /// In bs, this message translates to:
  /// **'ছবি তুলুন'**
  String get editTakePhoto;

  /// No description provided for @editChooseFromGallery.
  ///
  /// In bs, this message translates to:
  /// **'গ্যালারি থেকে বেছে নিন'**
  String get editChooseFromGallery;

  /// No description provided for @editRemovePhoto.
  ///
  /// In bs, this message translates to:
  /// **'ছবি মুছে ফেলুন'**
  String get editRemovePhoto;

  /// No description provided for @editProfileSaved.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল আপডেট হয়েছে'**
  String get editProfileSaved;

  /// No description provided for @editProfileSavedSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার প্রোফাইল সফলভাবে আপডেট হয়েছে।'**
  String get editProfileSavedSubtitle;

  /// No description provided for @editSelectGender.
  ///
  /// In bs, this message translates to:
  /// **'লিঙ্গ নির্বাচন করুন'**
  String get editSelectGender;

  /// No description provided for @genderMale.
  ///
  /// In bs, this message translates to:
  /// **'পুরুষ'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In bs, this message translates to:
  /// **'নারী'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In bs, this message translates to:
  /// **'অন্যান্য'**
  String get genderOther;

  /// No description provided for @goalWeightLoss.
  ///
  /// In bs, this message translates to:
  /// **'ওজন কমানো'**
  String get goalWeightLoss;

  /// No description provided for @goalWeightGain.
  ///
  /// In bs, this message translates to:
  /// **'ওজন বাড়ানো'**
  String get goalWeightGain;

  /// No description provided for @goalMaintainWeight.
  ///
  /// In bs, this message translates to:
  /// **'ওজন বজায় রাখা'**
  String get goalMaintainWeight;

  /// No description provided for @goalMuscleGain.
  ///
  /// In bs, this message translates to:
  /// **'মাসল গেইন'**
  String get goalMuscleGain;

  /// No description provided for @goalGeneralFitness.
  ///
  /// In bs, this message translates to:
  /// **'সাধারণ ফিটনেস'**
  String get goalGeneralFitness;

  /// No description provided for @activitySedentary.
  ///
  /// In bs, this message translates to:
  /// **'অচল'**
  String get activitySedentary;

  /// No description provided for @activityLight.
  ///
  /// In bs, this message translates to:
  /// **'সামান্য সক্রিয়'**
  String get activityLight;

  /// No description provided for @activityModerate.
  ///
  /// In bs, this message translates to:
  /// **'মাঝারি সক্রিয়'**
  String get activityModerate;

  /// No description provided for @activityVeryActive.
  ///
  /// In bs, this message translates to:
  /// **'খুব সক্রিয়'**
  String get activityVeryActive;

  /// No description provided for @activityAthlete.
  ///
  /// In bs, this message translates to:
  /// **'অ্যাথলিট'**
  String get activityAthlete;

  /// No description provided for @providerEmail.
  ///
  /// In bs, this message translates to:
  /// **'ইমেইল'**
  String get providerEmail;

  /// No description provided for @providerGoogle.
  ///
  /// In bs, this message translates to:
  /// **'গুগল'**
  String get providerGoogle;

  /// No description provided for @bmiSuggestionUnderweight.
  ///
  /// In bs, this message translates to:
  /// **'সুস্থ ওজনে পৌঁছাতে ক্যালোরি সাপ্লাস ও শক্তি প্রশিক্ষণ বিবেচনা করুন।'**
  String get bmiSuggestionUnderweight;

  /// No description provided for @bmiSuggestionNormal.
  ///
  /// In bs, this message translates to:
  /// **'দারুণ! সুষম খাদ্য ও নিয়মিত ব্যায়াম দিয়ে ওজন বজায় রাখুন।'**
  String get bmiSuggestionNormal;

  /// No description provided for @bmiSuggestionOverweight.
  ///
  /// In bs, this message translates to:
  /// **'নিয়মিত কার্ডিও ও ক্যালোরি ঘাটতি সুস্থ ওজনে পৌঁছাতে সাহায্য করবে।'**
  String get bmiSuggestionOverweight;

  /// No description provided for @bmiSuggestionObese.
  ///
  /// In bs, this message translates to:
  /// **'স্বাস্থ্য বিশেষজ্ঞের পরামর্শ নিন এবং ধীরে ধীরে ওজন কমানোর পরিকল্পনা অনুসরণ করুন।'**
  String get bmiSuggestionObese;

  /// No description provided for @profileNameRequired.
  ///
  /// In bs, this message translates to:
  /// **'নাম প্রয়োজন'**
  String get profileNameRequired;

  /// No description provided for @profileHeightInvalid.
  ///
  /// In bs, this message translates to:
  /// **'৬০ থেকে ২৫০ সেমি এর মধ্যে উচ্চতা লিখুন'**
  String get profileHeightInvalid;

  /// No description provided for @profileWeightInvalid.
  ///
  /// In bs, this message translates to:
  /// **'২০ থেকে ৪০০ কেজি এর মধ্যে ওজন লিখুন'**
  String get profileWeightInvalid;

  /// No description provided for @profileTargetWeightInvalid.
  ///
  /// In bs, this message translates to:
  /// **'২০ থেকে ৪০০ কেজি এর মধ্যে টার্গেট ওজন লিখুন'**
  String get profileTargetWeightInvalid;

  /// No description provided for @profileBirthInvalid.
  ///
  /// In bs, this message translates to:
  /// **'সঠিক জন্ম তারিখ নির্বাচন করুন'**
  String get profileBirthInvalid;

  /// No description provided for @profileCountryInvalid.
  ///
  /// In bs, this message translates to:
  /// **'দেশের নাম খুব দীর্ঘ'**
  String get profileCountryInvalid;

  /// No description provided for @profilePhotoChanged.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল ছবি আপডেট হয়েছে'**
  String get profilePhotoChanged;

  /// No description provided for @profilePhotoRemoved.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল ছবি মুছে ফেলা হয়েছে'**
  String get profilePhotoRemoved;

  /// No description provided for @profilePhotoError.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল ছবি আপডেট করা যায়নি'**
  String get profilePhotoError;

  /// No description provided for @commonClear.
  ///
  /// In bs, this message translates to:
  /// **'মুছুন'**
  String get commonClear;

  /// No description provided for @workoutHistory.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট ইতিহাস'**
  String get workoutHistory;

  /// No description provided for @workoutSearchHint.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট, ব্যায়াম খুঁজুন...'**
  String get workoutSearchHint;

  /// No description provided for @workoutSearchTitle.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট খুঁজুন'**
  String get workoutSearchTitle;

  /// No description provided for @workoutSearchEmptyTitle.
  ///
  /// In bs, this message translates to:
  /// **'লাইব্রেরি খুঁজুন'**
  String get workoutSearchEmptyTitle;

  /// No description provided for @workoutSearchEmptySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'নিখুঁত ওয়ার্কআউট পেতে কীওয়ার্ড লিখুন বা ফিল্টার ব্যবহার করুন।'**
  String get workoutSearchEmptySubtitle;

  /// No description provided for @workoutRecommended.
  ///
  /// In bs, this message translates to:
  /// **'আপনার জন্য সুপারিশকৃত'**
  String get workoutRecommended;

  /// No description provided for @workoutPopular.
  ///
  /// In bs, this message translates to:
  /// **'জনপ্রিয় ওয়ার্কআউট'**
  String get workoutPopular;

  /// No description provided for @workoutRecent.
  ///
  /// In bs, this message translates to:
  /// **'সম্প্রতি সম্পন্ন'**
  String get workoutRecent;

  /// No description provided for @workoutFavorites.
  ///
  /// In bs, this message translates to:
  /// **'পছন্দের তালিকা'**
  String get workoutFavorites;

  /// No description provided for @workoutEmptyTitle.
  ///
  /// In bs, this message translates to:
  /// **'এখনও কোনো ওয়ার্কআউট নেই'**
  String get workoutEmptyTitle;

  /// No description provided for @workoutEmptySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'আপনার ওয়ার্কআউট লাইব্রেরি এখানে দেখা যাবে।'**
  String get workoutEmptySubtitle;

  /// No description provided for @workoutContinueTitle.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট চালিয়ে যান'**
  String get workoutContinueTitle;

  /// No description provided for @workoutResume.
  ///
  /// In bs, this message translates to:
  /// **'চালিয়ে যান'**
  String get workoutResume;

  /// No description provided for @workoutExercises.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম'**
  String get workoutExercises;

  /// No description provided for @workoutExercise.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম'**
  String get workoutExercise;

  /// No description provided for @workoutRoutine.
  ///
  /// In bs, this message translates to:
  /// **'রুটিন'**
  String get workoutRoutine;

  /// No description provided for @workoutAbout.
  ///
  /// In bs, this message translates to:
  /// **'এই ওয়ার্কআউট সম্পর্কে'**
  String get workoutAbout;

  /// No description provided for @workoutMuscles.
  ///
  /// In bs, this message translates to:
  /// **'যে পেশি কাজ করে'**
  String get workoutMuscles;

  /// No description provided for @workoutEquipment.
  ///
  /// In bs, this message translates to:
  /// **'প্রয়োজনীয় সরঞ্জাম'**
  String get workoutEquipment;

  /// No description provided for @workoutStartNow.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট শুরু করুন'**
  String get workoutStartNow;

  /// No description provided for @workoutDifficultyBeginner.
  ///
  /// In bs, this message translates to:
  /// **'শিক্ষানবিস'**
  String get workoutDifficultyBeginner;

  /// No description provided for @workoutDifficultyIntermediate.
  ///
  /// In bs, this message translates to:
  /// **'মাঝারি'**
  String get workoutDifficultyIntermediate;

  /// No description provided for @workoutDifficultyAdvanced.
  ///
  /// In bs, this message translates to:
  /// **'অগ্রসর'**
  String get workoutDifficultyAdvanced;

  /// No description provided for @workoutSets.
  ///
  /// In bs, this message translates to:
  /// **'সেট'**
  String get workoutSets;

  /// No description provided for @workoutReps.
  ///
  /// In bs, this message translates to:
  /// **'রিপ'**
  String get workoutReps;

  /// No description provided for @workoutSeconds.
  ///
  /// In bs, this message translates to:
  /// **'সেকেন্ড'**
  String get workoutSeconds;

  /// No description provided for @workoutTimed.
  ///
  /// In bs, this message translates to:
  /// **'সময়ভিত্তিক'**
  String get workoutTimed;

  /// No description provided for @workoutRest.
  ///
  /// In bs, this message translates to:
  /// **'বিশ্রাম'**
  String get workoutRest;

  /// No description provided for @workoutRestTitle.
  ///
  /// In bs, this message translates to:
  /// **'বিশ্রাম'**
  String get workoutRestTitle;

  /// No description provided for @workoutRestTime.
  ///
  /// In bs, this message translates to:
  /// **'বিশ্রামের সময়'**
  String get workoutRestTime;

  /// No description provided for @workoutSkipRest.
  ///
  /// In bs, this message translates to:
  /// **'বিশ্রাম এড়িয়ে যান'**
  String get workoutSkipRest;

  /// No description provided for @workoutEndRest.
  ///
  /// In bs, this message translates to:
  /// **'বিশ্রাম শেষ করুন'**
  String get workoutEndRest;

  /// No description provided for @workoutComplete.
  ///
  /// In bs, this message translates to:
  /// **'সম্পন্ন করুন'**
  String get workoutComplete;

  /// No description provided for @workoutFinish.
  ///
  /// In bs, this message translates to:
  /// **'সব শেষ!'**
  String get workoutFinish;

  /// No description provided for @workoutExitTitle.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট ছেড়ে যাবেন?'**
  String get workoutExitTitle;

  /// No description provided for @workoutExitMessage.
  ///
  /// In bs, this message translates to:
  /// **'আপনার অগ্রগতি সংরক্ষিত থাকবে, পরে আবার চালিয়ে নিতে পারবেন।'**
  String get workoutExitMessage;

  /// No description provided for @workoutExit.
  ///
  /// In bs, this message translates to:
  /// **'ছেড়ে যান'**
  String get workoutExit;

  /// No description provided for @workoutDuration.
  ///
  /// In bs, this message translates to:
  /// **'সময়কাল'**
  String get workoutDuration;

  /// No description provided for @workoutCaloriesBurned.
  ///
  /// In bs, this message translates to:
  /// **'পোড়া ক্যালোরি'**
  String get workoutCaloriesBurned;

  /// No description provided for @workoutTotalWorkouts.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট'**
  String get workoutTotalWorkouts;

  /// No description provided for @workoutNoHistory.
  ///
  /// In bs, this message translates to:
  /// **'এখনও কোনো ওয়ার্কআউট নেই'**
  String get workoutNoHistory;

  /// No description provided for @workoutNoHistorySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'একটি ওয়ার্কআউট সম্পন্ন করুন, এটি এখানে দেখা যাবে।'**
  String get workoutNoHistorySubtitle;

  /// No description provided for @workoutCompleteTitle.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট সম্পন্ন!'**
  String get workoutCompleteTitle;

  /// No description provided for @workoutCompleteSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'দারুণ কাজ! এই ধারাবাহিকতা বজায় রাখুন।'**
  String get workoutCompleteSubtitle;

  /// No description provided for @workoutNewAchievements.
  ///
  /// In bs, this message translates to:
  /// **'অর্জন উন্মোচিত হয়েছে'**
  String get workoutNewAchievements;

  /// No description provided for @workoutDone.
  ///
  /// In bs, this message translates to:
  /// **'সম্পন্ন'**
  String get workoutDone;

  /// No description provided for @workoutFilterAll.
  ///
  /// In bs, this message translates to:
  /// **'সব'**
  String get workoutFilterAll;

  /// No description provided for @workoutFilterDifficulty.
  ///
  /// In bs, this message translates to:
  /// **'স্তর'**
  String get workoutFilterDifficulty;

  /// No description provided for @workoutFilterDuration.
  ///
  /// In bs, this message translates to:
  /// **'সময়কাল'**
  String get workoutFilterDuration;

  /// No description provided for @workoutFilterShort.
  ///
  /// In bs, this message translates to:
  /// **'সংক্ষিপ্ত (<২০ মিনিট)'**
  String get workoutFilterShort;

  /// No description provided for @workoutFilterMedium.
  ///
  /// In bs, this message translates to:
  /// **'মাঝারি (২০-৪০ মিনিট)'**
  String get workoutFilterMedium;

  /// No description provided for @workoutFilterLong.
  ///
  /// In bs, this message translates to:
  /// **'দীর্ঘ (৪০+ মিনিট)'**
  String get workoutFilterLong;

  /// No description provided for @workoutFilterGoal.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য'**
  String get workoutFilterGoal;

  /// No description provided for @workoutFilterEquipment.
  ///
  /// In bs, this message translates to:
  /// **'সরঞ্জাম'**
  String get workoutFilterEquipment;

  /// No description provided for @workoutClearFilters.
  ///
  /// In bs, this message translates to:
  /// **'ফিল্টার মুছুন'**
  String get workoutClearFilters;

  /// No description provided for @exerciseLibrary.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম লাইব্রেরি'**
  String get exerciseLibrary;

  /// No description provided for @exerciseLibrarySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'পেশি গ্রুপ অনুযায়ী ব্যায়াম দেখুন'**
  String get exerciseLibrarySubtitle;

  /// No description provided for @exerciseSearchHint.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম খুঁজুন...'**
  String get exerciseSearchHint;

  /// No description provided for @exerciseSearchTitle.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম খুঁজুন'**
  String get exerciseSearchTitle;

  /// No description provided for @exerciseSearchEmptyTitle.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম লাইব্রেরি খুঁজুন'**
  String get exerciseSearchEmptyTitle;

  /// No description provided for @exerciseSearchEmptySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'কীওয়ার্ড লিখুন বা বিভাগ, স্তর ও সরঞ্জাম দিয়ে ফিল্টার করুন।'**
  String get exerciseSearchEmptySubtitle;

  /// No description provided for @exerciseAll.
  ///
  /// In bs, this message translates to:
  /// **'সব'**
  String get exerciseAll;

  /// No description provided for @exerciseFavorites.
  ///
  /// In bs, this message translates to:
  /// **'পছন্দের তালিকা'**
  String get exerciseFavorites;

  /// No description provided for @exerciseFavoritesOnly.
  ///
  /// In bs, this message translates to:
  /// **'শুধু পছন্দের'**
  String get exerciseFavoritesOnly;

  /// No description provided for @exerciseNoFavorites.
  ///
  /// In bs, this message translates to:
  /// **'এখনও কোনো পছন্দ নেই'**
  String get exerciseNoFavorites;

  /// No description provided for @exerciseNoFavoritesSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'যেকোনো ব্যায়ামের হার্ট আইকনে চাপ দিলে এটি এখানে দেখা যাবে।'**
  String get exerciseNoFavoritesSubtitle;

  /// No description provided for @exerciseNoResults.
  ///
  /// In bs, this message translates to:
  /// **'কোনো ব্যায়াম পাওয়া যায়নি'**
  String get exerciseNoResults;

  /// No description provided for @exerciseNoResultsSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'অন্য কীওয়ার্ড বা ফিল্টার দিয়ে চেষ্টা করুন।'**
  String get exerciseNoResultsSubtitle;

  /// No description provided for @exerciseTargetMuscle.
  ///
  /// In bs, this message translates to:
  /// **'প্রধান পেশি'**
  String get exerciseTargetMuscle;

  /// No description provided for @exerciseSecondaryMuscle.
  ///
  /// In bs, this message translates to:
  /// **'সহায়ক পেশি'**
  String get exerciseSecondaryMuscle;

  /// No description provided for @exerciseHowTo.
  ///
  /// In bs, this message translates to:
  /// **'যেভাবে করবেন'**
  String get exerciseHowTo;

  /// No description provided for @exerciseTips.
  ///
  /// In bs, this message translates to:
  /// **'পরামর্শ'**
  String get exerciseTips;

  /// No description provided for @exerciseCommonMistakes.
  ///
  /// In bs, this message translates to:
  /// **'সাধারণ ভুল'**
  String get exerciseCommonMistakes;

  /// No description provided for @exerciseSafety.
  ///
  /// In bs, this message translates to:
  /// **'নিরাপত্তা নির্দেশনা'**
  String get exerciseSafety;

  /// No description provided for @exerciseAbout.
  ///
  /// In bs, this message translates to:
  /// **'এই ব্যায়াম সম্পর্কে'**
  String get exerciseAbout;

  /// No description provided for @exerciseStart.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম শুরু করুন'**
  String get exerciseStart;

  /// No description provided for @exerciseSets.
  ///
  /// In bs, this message translates to:
  /// **'সেট'**
  String get exerciseSets;

  /// No description provided for @exerciseReps.
  ///
  /// In bs, this message translates to:
  /// **'রিপ'**
  String get exerciseReps;

  /// No description provided for @exerciseRest.
  ///
  /// In bs, this message translates to:
  /// **'বিশ্রাম'**
  String get exerciseRest;

  /// No description provided for @exerciseSetOf.
  ///
  /// In bs, this message translates to:
  /// **'সেট {current} / {total}'**
  String exerciseSetOf(Object current, Object total);

  /// No description provided for @exerciseNextUp.
  ///
  /// In bs, this message translates to:
  /// **'পরবর্তী'**
  String get exerciseNextUp;

  /// No description provided for @exerciseCompleteTitle.
  ///
  /// In bs, this message translates to:
  /// **'ব্যায়াম সম্পন্ন!'**
  String get exerciseCompleteTitle;

  /// No description provided for @exerciseCompleteSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'দারুণ কাজ! চালিয়ে যান।'**
  String get exerciseCompleteSubtitle;

  /// No description provided for @exerciseCaloriesEstimate.
  ///
  /// In bs, this message translates to:
  /// **'ক্যালোরি'**
  String get exerciseCaloriesEstimate;

  /// No description provided for @exerciseDuration.
  ///
  /// In bs, this message translates to:
  /// **'সময়কাল'**
  String get exerciseDuration;

  /// No description provided for @exerciseAllCategories.
  ///
  /// In bs, this message translates to:
  /// **'সব বিভাগ'**
  String get exerciseAllCategories;

  /// No description provided for @workoutSummary.
  ///
  /// In bs, this message translates to:
  /// **'ওয়ার্কআউট সারাংশ'**
  String get workoutSummary;

  /// No description provided for @workoutSummaryBadges.
  ///
  /// In bs, this message translates to:
  /// **'অর্জিত ব্যাজ'**
  String get workoutSummaryBadges;

  /// No description provided for @workoutSummaryStreak.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান স্ট্রিক'**
  String get workoutSummaryStreak;

  /// No description provided for @workoutSummaryCompletion.
  ///
  /// In bs, this message translates to:
  /// **'সম্পন্নের হার'**
  String get workoutSummaryCompletion;

  /// No description provided for @workoutSummaryMotivation.
  ///
  /// In bs, this message translates to:
  /// **'প্রতিটি রিপ গণনা করে। চালিয়ে যান!'**
  String get workoutSummaryMotivation;

  /// No description provided for @workoutSummaryExercisesDone.
  ///
  /// In bs, this message translates to:
  /// **'{completed} / {total} ব্যায়াম সম্পন্ন'**
  String workoutSummaryExercisesDone(Object completed, Object total);

  /// No description provided for @workoutSummaryDays.
  ///
  /// In bs, this message translates to:
  /// **'দিন'**
  String get workoutSummaryDays;

  /// No description provided for @foodCategoryRice.
  ///
  /// In bs, this message translates to:
  /// **'চাল'**
  String get foodCategoryRice;

  /// No description provided for @foodCategoryBread.
  ///
  /// In bs, this message translates to:
  /// **'রুটি'**
  String get foodCategoryBread;

  /// No description provided for @foodCategoryMeat.
  ///
  /// In bs, this message translates to:
  /// **'মাংস'**
  String get foodCategoryMeat;

  /// No description provided for @foodCategoryChicken.
  ///
  /// In bs, this message translates to:
  /// **'মুরগি'**
  String get foodCategoryChicken;

  /// No description provided for @foodCategoryFish.
  ///
  /// In bs, this message translates to:
  /// **'মাছ'**
  String get foodCategoryFish;

  /// No description provided for @foodCategoryEgg.
  ///
  /// In bs, this message translates to:
  /// **'ডিম'**
  String get foodCategoryEgg;

  /// No description provided for @foodCategoryVegetables.
  ///
  /// In bs, this message translates to:
  /// **'সবজি'**
  String get foodCategoryVegetables;

  /// No description provided for @foodCategoryFruits.
  ///
  /// In bs, this message translates to:
  /// **'ফল'**
  String get foodCategoryFruits;

  /// No description provided for @foodCategoryMilk.
  ///
  /// In bs, this message translates to:
  /// **'দুধ'**
  String get foodCategoryMilk;

  /// No description provided for @foodCategoryDairy.
  ///
  /// In bs, this message translates to:
  /// **'দুগ্ধজাত'**
  String get foodCategoryDairy;

  /// No description provided for @foodCategoryFastFood.
  ///
  /// In bs, this message translates to:
  /// **'ফাস্ট ফুড'**
  String get foodCategoryFastFood;

  /// No description provided for @foodCategoryDessert.
  ///
  /// In bs, this message translates to:
  /// **'মিষ্টান্ন'**
  String get foodCategoryDessert;

  /// No description provided for @foodCategoryDrinks.
  ///
  /// In bs, this message translates to:
  /// **'পানীয়'**
  String get foodCategoryDrinks;

  /// No description provided for @foodCategoryNuts.
  ///
  /// In bs, this message translates to:
  /// **'বাদাম'**
  String get foodCategoryNuts;

  /// No description provided for @foodCategorySeeds.
  ///
  /// In bs, this message translates to:
  /// **'বীজ'**
  String get foodCategorySeeds;

  /// No description provided for @foodCategoryHealthySnacks.
  ///
  /// In bs, this message translates to:
  /// **'স্বাস্থ্যকর স্ন্যাকস'**
  String get foodCategoryHealthySnacks;

  /// No description provided for @nutritionKcal.
  ///
  /// In bs, this message translates to:
  /// **'কিলোক্যালরি'**
  String get nutritionKcal;

  /// No description provided for @nutritionMacros.
  ///
  /// In bs, this message translates to:
  /// **'ম্যাক্রো'**
  String get nutritionMacros;

  /// No description provided for @nutritionProtein.
  ///
  /// In bs, this message translates to:
  /// **'প্রোটিন'**
  String get nutritionProtein;

  /// No description provided for @nutritionCarbs.
  ///
  /// In bs, this message translates to:
  /// **'কার্ব'**
  String get nutritionCarbs;

  /// No description provided for @nutritionFat.
  ///
  /// In bs, this message translates to:
  /// **'ফ্যাট'**
  String get nutritionFat;

  /// No description provided for @nutritionRemaining.
  ///
  /// In bs, this message translates to:
  /// **'বাকি আছে'**
  String get nutritionRemaining;

  /// No description provided for @nutritionGoalMet.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য অর্জনে এগিয়ে'**
  String get nutritionGoalMet;

  /// No description provided for @nutritionGoalProgress.
  ///
  /// In bs, this message translates to:
  /// **'প্রগতি চলছে'**
  String get nutritionGoalProgress;

  /// No description provided for @nutritionWaterIntake.
  ///
  /// In bs, this message translates to:
  /// **'পানি গ্রহণ'**
  String get nutritionWaterIntake;

  /// No description provided for @nutritionWaterHint.
  ///
  /// In bs, this message translates to:
  /// **'ওয়াটার মডিউল থেকে ট্র্যাক করা হয়'**
  String get nutritionWaterHint;

  /// No description provided for @nutritionMeals.
  ///
  /// In bs, this message translates to:
  /// **'খাবার'**
  String get nutritionMeals;

  /// No description provided for @nutritionMealEmpty.
  ///
  /// In bs, this message translates to:
  /// **'এখনো কোনো খাবার যোগ হয়নি'**
  String get nutritionMealEmpty;

  /// No description provided for @nutritionItems.
  ///
  /// In bs, this message translates to:
  /// **'টি'**
  String get nutritionItems;

  /// No description provided for @nutritionNoFoodLogged.
  ///
  /// In bs, this message translates to:
  /// **'এই খাবারে এখনো কিছু লগ হয়নি।'**
  String get nutritionNoFoodLogged;

  /// No description provided for @nutritionAddFood.
  ///
  /// In bs, this message translates to:
  /// **'খাবার যোগ করুন'**
  String get nutritionAddFood;

  /// No description provided for @nutritionAddToMeal.
  ///
  /// In bs, this message translates to:
  /// **'খাবারে যোগ করুন'**
  String get nutritionAddToMeal;

  /// No description provided for @nutritionAddToLog.
  ///
  /// In bs, this message translates to:
  /// **'লগে যোগ করুন'**
  String get nutritionAddToLog;

  /// No description provided for @nutritionMealType.
  ///
  /// In bs, this message translates to:
  /// **'খাবারের ধরন'**
  String get nutritionMealType;

  /// No description provided for @nutritionQuantity.
  ///
  /// In bs, this message translates to:
  /// **'পরিমাণ'**
  String get nutritionQuantity;

  /// No description provided for @nutritionCalories.
  ///
  /// In bs, this message translates to:
  /// **'ক্যালোরি'**
  String get nutritionCalories;

  /// No description provided for @nutritionSelectMeal.
  ///
  /// In bs, this message translates to:
  /// **'আগে একটি খাবার স্লট বেছে নিন'**
  String get nutritionSelectMeal;

  /// No description provided for @nutritionFoodAdded.
  ///
  /// In bs, this message translates to:
  /// **'খাবার যোগ হয়েছে'**
  String get nutritionFoodAdded;

  /// No description provided for @nutritionEditQuantity.
  ///
  /// In bs, this message translates to:
  /// **'পরিমাণ পরিবর্তন'**
  String get nutritionEditQuantity;

  /// No description provided for @nutritionRemoveFood.
  ///
  /// In bs, this message translates to:
  /// **'খাবার সরান'**
  String get nutritionRemoveFood;

  /// No description provided for @nutritionRemoveFoodMessage.
  ///
  /// In bs, this message translates to:
  /// **'লগ থেকে এই খাবারটি সরিয়ে ফেলবেন?'**
  String get nutritionRemoveFoodMessage;

  /// No description provided for @nutritionDuplicate.
  ///
  /// In bs, this message translates to:
  /// **'ডুপ্লিকেট'**
  String get nutritionDuplicate;

  /// No description provided for @nutritionCopyYesterday.
  ///
  /// In bs, this message translates to:
  /// **'গতকাল কপি করুন'**
  String get nutritionCopyYesterday;

  /// No description provided for @nutritionCopyYesterdayDone.
  ///
  /// In bs, this message translates to:
  /// **'গতকাল থেকে {count}টি আইটেম কপি হয়েছে'**
  String nutritionCopyYesterdayDone(Object count);

  /// No description provided for @nutritionDaysAgo.
  ///
  /// In bs, this message translates to:
  /// **'দিন আগে'**
  String get nutritionDaysAgo;

  /// No description provided for @nutritionDaysLater.
  ///
  /// In bs, this message translates to:
  /// **'দিন পরে'**
  String get nutritionDaysLater;

  /// No description provided for @nutritionDaysShort.
  ///
  /// In bs, this message translates to:
  /// **'দিন'**
  String get nutritionDaysShort;

  /// No description provided for @nutritionMacroTracker.
  ///
  /// In bs, this message translates to:
  /// **'ম্যাক্রো ট্র্যাকার'**
  String get nutritionMacroTracker;

  /// No description provided for @nutritionHistory.
  ///
  /// In bs, this message translates to:
  /// **'পুষ্টি ইতিহাস'**
  String get nutritionHistory;

  /// No description provided for @nutritionAvgMacros.
  ///
  /// In bs, this message translates to:
  /// **'গড় ম্যাক্রো'**
  String get nutritionAvgMacros;

  /// No description provided for @nutritionAvgCalories.
  ///
  /// In bs, this message translates to:
  /// **'গড় কিলোক্যালরি'**
  String get nutritionAvgCalories;

  /// No description provided for @nutritionAvgWater.
  ///
  /// In bs, this message translates to:
  /// **'গড় পানি'**
  String get nutritionAvgWater;

  /// No description provided for @nutritionLoggedDays.
  ///
  /// In bs, this message translates to:
  /// **'লগ হওয়া দিন'**
  String get nutritionLoggedDays;

  /// No description provided for @nutritionCalorieTrend.
  ///
  /// In bs, this message translates to:
  /// **'ক্যালোরির ধারা'**
  String get nutritionCalorieTrend;

  /// No description provided for @nutritionGoalAdherence.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য পূরণের হার'**
  String get nutritionGoalAdherence;

  /// No description provided for @nutritionDailyBreakdown.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক বিশ্লেষণ'**
  String get nutritionDailyBreakdown;

  /// No description provided for @nutritionNoHistory.
  ///
  /// In bs, this message translates to:
  /// **'এই সময়ের কোনো তথ্য নেই'**
  String get nutritionNoHistory;

  /// No description provided for @nutritionNoHistorySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'খাবার লগ করুন, ইতিহাস এখানে দেখা যাবে।'**
  String get nutritionNoHistorySubtitle;

  /// No description provided for @nutritionFoodDatabase.
  ///
  /// In bs, this message translates to:
  /// **'খাদ্য ডেটাবেস'**
  String get nutritionFoodDatabase;

  /// No description provided for @nutritionFoodSearchHint.
  ///
  /// In bs, this message translates to:
  /// **'খাবার খুঁজুন...'**
  String get nutritionFoodSearchHint;

  /// No description provided for @nutritionAllFoods.
  ///
  /// In bs, this message translates to:
  /// **'সব খাবার'**
  String get nutritionAllFoods;

  /// No description provided for @nutritionFavorites.
  ///
  /// In bs, this message translates to:
  /// **'প্রিয়'**
  String get nutritionFavorites;

  /// No description provided for @nutritionRecent.
  ///
  /// In bs, this message translates to:
  /// **'সাম্প্রতিক'**
  String get nutritionRecent;

  /// No description provided for @nutritionFrequent.
  ///
  /// In bs, this message translates to:
  /// **'ঘন ঘন'**
  String get nutritionFrequent;

  /// No description provided for @nutritionNoResults.
  ///
  /// In bs, this message translates to:
  /// **'কোনো খাবার পাওয়া যায়নি'**
  String get nutritionNoResults;

  /// No description provided for @nutritionNoResultsSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'অন্য কিছু খুঁজুন বা ফিল্টার বদলান।'**
  String get nutritionNoResultsSubtitle;

  /// No description provided for @nutritionNoFavorites.
  ///
  /// In bs, this message translates to:
  /// **'এখনো কোনো প্রিয় নেই'**
  String get nutritionNoFavorites;

  /// No description provided for @nutritionNoFavoritesSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'যেকোনো খাবারে হার্ট চেপে এখানে সংরক্ষণ করুন।'**
  String get nutritionNoFavoritesSubtitle;

  /// No description provided for @nutritionNoRecent.
  ///
  /// In bs, this message translates to:
  /// **'সাম্প্রতিক খাবার নেই'**
  String get nutritionNoRecent;

  /// No description provided for @nutritionNoRecentSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'যে খাবার লগ করবেন তা এখানে দেখা যাবে।'**
  String get nutritionNoRecentSubtitle;

  /// No description provided for @nutritionNoFrequent.
  ///
  /// In bs, this message translates to:
  /// **'ঘন ঘন খাবার নেই'**
  String get nutritionNoFrequent;

  /// No description provided for @nutritionNoFrequentSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'যে খাবার বারবার লগ করবেন তা এখানে দেখা যাবে।'**
  String get nutritionNoFrequentSubtitle;

  /// No description provided for @nutritionNutritionFacts.
  ///
  /// In bs, this message translates to:
  /// **'পুষ্টি উপাদান'**
  String get nutritionNutritionFacts;

  /// No description provided for @nutritionServingSize.
  ///
  /// In bs, this message translates to:
  /// **'পরিবেশন পরিমাণ'**
  String get nutritionServingSize;

  /// No description provided for @nutritionFiber.
  ///
  /// In bs, this message translates to:
  /// **'আঁশ'**
  String get nutritionFiber;

  /// No description provided for @nutritionSugar.
  ///
  /// In bs, this message translates to:
  /// **'চিনি'**
  String get nutritionSugar;

  /// No description provided for @nutritionSodium.
  ///
  /// In bs, this message translates to:
  /// **'সোডিয়াম'**
  String get nutritionSodium;

  /// No description provided for @nutritionPotassium.
  ///
  /// In bs, this message translates to:
  /// **'পটাশিয়াম'**
  String get nutritionPotassium;

  /// No description provided for @nutritionCalcium.
  ///
  /// In bs, this message translates to:
  /// **'ক্যালসিয়াম'**
  String get nutritionCalcium;

  /// No description provided for @nutritionIron.
  ///
  /// In bs, this message translates to:
  /// **'আয়রন'**
  String get nutritionIron;

  /// No description provided for @nutritionVitaminA.
  ///
  /// In bs, this message translates to:
  /// **'ভিটামিন এ'**
  String get nutritionVitaminA;

  /// No description provided for @nutritionVitaminC.
  ///
  /// In bs, this message translates to:
  /// **'ভিটামিন সি'**
  String get nutritionVitaminC;

  /// No description provided for @nutritionWaterContent.
  ///
  /// In bs, this message translates to:
  /// **'পানির পরিমাণ'**
  String get nutritionWaterContent;

  /// No description provided for @nutritionMealPlanner.
  ///
  /// In bs, this message translates to:
  /// **'খাবার পরিকল্পনা'**
  String get nutritionMealPlanner;

  /// No description provided for @nutritionNewTemplate.
  ///
  /// In bs, this message translates to:
  /// **'নতুন টেমপ্লেট'**
  String get nutritionNewTemplate;

  /// No description provided for @nutritionNoTemplates.
  ///
  /// In bs, this message translates to:
  /// **'কোনো খাবার টেমপ্লেট নেই'**
  String get nutritionNoTemplates;

  /// No description provided for @nutritionNoTemplatesSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'প্রিয় খাবার সংরক্ষণ করুন এবং এক ট্যাপে লগ করুন।'**
  String get nutritionNoTemplatesSubtitle;

  /// No description provided for @nutritionSaveTemplate.
  ///
  /// In bs, this message translates to:
  /// **'টেমপ্লেট সংরক্ষণ করুন'**
  String get nutritionSaveTemplate;

  /// No description provided for @nutritionTemplateName.
  ///
  /// In bs, this message translates to:
  /// **'টেমপ্লেটের নাম'**
  String get nutritionTemplateName;

  /// No description provided for @nutritionTemplateNameHint.
  ///
  /// In bs, this message translates to:
  /// **'যেমন: ওয়ার্কআউট পরবর্তী খাবার'**
  String get nutritionTemplateNameHint;

  /// No description provided for @nutritionTemplateNameRequired.
  ///
  /// In bs, this message translates to:
  /// **'টেমপ্লেটের নাম লিখুন'**
  String get nutritionTemplateNameRequired;

  /// No description provided for @nutritionTemplateNoFoods.
  ///
  /// In bs, this message translates to:
  /// **'এখনো কোনো খাবার বাছাই করা হয়নি'**
  String get nutritionTemplateNoFoods;

  /// No description provided for @nutritionSelectedFoods.
  ///
  /// In bs, this message translates to:
  /// **'{count}টি খাবার বাছাই হয়েছে'**
  String nutritionSelectedFoods(Object count);

  /// No description provided for @nutritionTemplateSaved.
  ///
  /// In bs, this message translates to:
  /// **'টেমপ্লেট সংরক্ষিত হয়েছে'**
  String get nutritionTemplateSaved;

  /// No description provided for @nutritionTemplateLogged.
  ///
  /// In bs, this message translates to:
  /// **'টেমপ্লেট লগ হয়েছে'**
  String get nutritionTemplateLogged;

  /// No description provided for @nutritionTemplateDeleted.
  ///
  /// In bs, this message translates to:
  /// **'টেমপ্লেট মুছে ফেলা হয়েছে'**
  String get nutritionTemplateDeleted;

  /// No description provided for @nutritionLogTemplate.
  ///
  /// In bs, this message translates to:
  /// **'টেমপ্লেট লগ করুন'**
  String get nutritionLogTemplate;

  /// No description provided for @nutritionDeleteTemplate.
  ///
  /// In bs, this message translates to:
  /// **'টেমপ্লেট মুছবেন?'**
  String get nutritionDeleteTemplate;

  /// No description provided for @nutritionDeleteTemplateMessage.
  ///
  /// In bs, this message translates to:
  /// **'\'{name}\' মুছে ফেলবেন? এটি ফেরানো যাবে না।'**
  String nutritionDeleteTemplateMessage(Object name);

  /// No description provided for @waterTitle.
  ///
  /// In bs, this message translates to:
  /// **'পানি'**
  String get waterTitle;

  /// No description provided for @waterTracker.
  ///
  /// In bs, this message translates to:
  /// **'ওয়াটার ট্র্যাকার'**
  String get waterTracker;

  /// No description provided for @waterHistory.
  ///
  /// In bs, this message translates to:
  /// **'পানির ইতিহাস'**
  String get waterHistory;

  /// No description provided for @waterStatistics.
  ///
  /// In bs, this message translates to:
  /// **'পরিসংখ্যান'**
  String get waterStatistics;

  /// No description provided for @waterReminders.
  ///
  /// In bs, this message translates to:
  /// **'রিমাইন্ডার'**
  String get waterReminders;

  /// No description provided for @waterHydration.
  ///
  /// In bs, this message translates to:
  /// **'হাইড্রেশন'**
  String get waterHydration;

  /// No description provided for @waterIntakeToday.
  ///
  /// In bs, this message translates to:
  /// **'আজকের পানি'**
  String get waterIntakeToday;

  /// No description provided for @waterDailyGoal.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক লক্ষ্য'**
  String get waterDailyGoal;

  /// No description provided for @waterRemaining.
  ///
  /// In bs, this message translates to:
  /// **'বাকি আছে'**
  String get waterRemaining;

  /// No description provided for @waterGoalProgress.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য অগ্রগতি'**
  String get waterGoalProgress;

  /// No description provided for @waterQuickAdd.
  ///
  /// In bs, this message translates to:
  /// **'দ্রুত যোগ করুন'**
  String get waterQuickAdd;

  /// No description provided for @waterCustomAmount.
  ///
  /// In bs, this message translates to:
  /// **'নিজস্ব পরিমাণ'**
  String get waterCustomAmount;

  /// No description provided for @waterNote.
  ///
  /// In bs, this message translates to:
  /// **'নোট (ঐচ্ছিক)'**
  String get waterNote;

  /// No description provided for @waterLogSuccess.
  ///
  /// In bs, this message translates to:
  /// **'পানি যোগ হয়েছে'**
  String get waterLogSuccess;

  /// No description provided for @waterLogUpdated.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি আপডেট হয়েছে'**
  String get waterLogUpdated;

  /// No description provided for @waterLogDeleted.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি মুছে ফেলা হয়েছে'**
  String get waterLogDeleted;

  /// No description provided for @waterEntries.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি'**
  String get waterEntries;

  /// No description provided for @waterNoEntries.
  ///
  /// In bs, this message translates to:
  /// **'আজ কোনো পানি যোগ হয়নি'**
  String get waterNoEntries;

  /// No description provided for @waterNoEntriesSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'নিচের বোতাম থেকে পানি যোগ করুন'**
  String get waterNoEntriesSubtitle;

  /// No description provided for @waterSetGoal.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য নির্ধারণ করুন'**
  String get waterSetGoal;

  /// No description provided for @waterEditGoal.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য পরিবর্তন করুন'**
  String get waterEditGoal;

  /// No description provided for @waterGoalSheetTitle.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক পানির লক্ষ্য'**
  String get waterGoalSheetTitle;

  /// No description provided for @waterGoalSuggested.
  ///
  /// In bs, this message translates to:
  /// **'প্রস্তাবিত লক্ষ্য'**
  String get waterGoalSuggested;

  /// No description provided for @waterGoalSaved.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য সংরক্ষিত হয়েছে'**
  String get waterGoalSaved;

  /// No description provided for @waterStatusNeedsWater.
  ///
  /// In bs, this message translates to:
  /// **'আরও পানি দরকার'**
  String get waterStatusNeedsWater;

  /// No description provided for @waterStatusGettingThere.
  ///
  /// In bs, this message translates to:
  /// **'ভালো যাচ্ছে'**
  String get waterStatusGettingThere;

  /// No description provided for @waterStatusNearlyThere.
  ///
  /// In bs, this message translates to:
  /// **'প্রায় শেষ'**
  String get waterStatusNearlyThere;

  /// No description provided for @waterStatusGoalMet.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য পূরণ হয়েছে'**
  String get waterStatusGoalMet;

  /// No description provided for @waterStatusExceeded.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য ছাড়িয়ে গেছে'**
  String get waterStatusExceeded;

  /// No description provided for @waterEditEntry.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি সম্পাদনা'**
  String get waterEditEntry;

  /// No description provided for @waterDeleteEntry.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি মুছবেন?'**
  String get waterDeleteEntry;

  /// No description provided for @waterDeleteEntryMessage.
  ///
  /// In bs, this message translates to:
  /// **'এই পানির এন্ট্রি মুছে ফেলা হবে।'**
  String get waterDeleteEntryMessage;

  /// No description provided for @waterHistoryDaily.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক'**
  String get waterHistoryDaily;

  /// No description provided for @waterHistoryWeekly.
  ///
  /// In bs, this message translates to:
  /// **'সাপ্তাহিক'**
  String get waterHistoryWeekly;

  /// No description provided for @waterHistoryMonthly.
  ///
  /// In bs, this message translates to:
  /// **'মাসিক'**
  String get waterHistoryMonthly;

  /// No description provided for @waterHistoryYearly.
  ///
  /// In bs, this message translates to:
  /// **'বার্ষিক'**
  String get waterHistoryYearly;

  /// No description provided for @waterHistoryTotal.
  ///
  /// In bs, this message translates to:
  /// **'মোট'**
  String get waterHistoryTotal;

  /// No description provided for @waterHistoryAverage.
  ///
  /// In bs, this message translates to:
  /// **'গড়'**
  String get waterHistoryAverage;

  /// No description provided for @waterHistoryBest.
  ///
  /// In bs, this message translates to:
  /// **'সর্বোচ্চ'**
  String get waterHistoryBest;

  /// No description provided for @waterHistoryLogged.
  ///
  /// In bs, this message translates to:
  /// **'লগ হওয়া'**
  String get waterHistoryLogged;

  /// No description provided for @waterNoHistory.
  ///
  /// In bs, this message translates to:
  /// **'কোনো তথ্য নেই'**
  String get waterNoHistory;

  /// No description provided for @waterNoHistorySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'প্রতিদিন পানি যোগ করলে এখানে ইতিহাস দেখতে পাবেন'**
  String get waterNoHistorySubtitle;

  /// No description provided for @waterStatAvgDaily.
  ///
  /// In bs, this message translates to:
  /// **'গড় দৈনিক গ্রহণ'**
  String get waterStatAvgDaily;

  /// No description provided for @waterStatBestDay.
  ///
  /// In bs, this message translates to:
  /// **'সেরা দিন'**
  String get waterStatBestDay;

  /// No description provided for @waterStatCurrentStreak.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান ধারা'**
  String get waterStatCurrentStreak;

  /// No description provided for @waterStatLongestStreak.
  ///
  /// In bs, this message translates to:
  /// **'সর্বোচ্চ ধারা'**
  String get waterStatLongestStreak;

  /// No description provided for @waterStatTotalConsumed.
  ///
  /// In bs, this message translates to:
  /// **'মোট পানি'**
  String get waterStatTotalConsumed;

  /// No description provided for @waterStatTotalEntries.
  ///
  /// In bs, this message translates to:
  /// **'মোট এন্ট্রি'**
  String get waterStatTotalEntries;

  /// No description provided for @waterStatTrackedDays.
  ///
  /// In bs, this message translates to:
  /// **'ট্র্যাক করা দিন'**
  String get waterStatTrackedDays;

  /// No description provided for @waterStreakDays.
  ///
  /// In bs, this message translates to:
  /// **'{count} দিন'**
  String waterStreakDays(Object count);

  /// No description provided for @waterReminderMorning.
  ///
  /// In bs, this message translates to:
  /// **'সকালের রিমাইন্ডার'**
  String get waterReminderMorning;

  /// No description provided for @waterReminderAfternoon.
  ///
  /// In bs, this message translates to:
  /// **'দুপুরের রিমাইন্ডার'**
  String get waterReminderAfternoon;

  /// No description provided for @waterReminderEvening.
  ///
  /// In bs, this message translates to:
  /// **'সন্ধ্যার রিমাইন্ডার'**
  String get waterReminderEvening;

  /// No description provided for @waterReminderCustom.
  ///
  /// In bs, this message translates to:
  /// **'নিজস্ব রিমাইন্ডার'**
  String get waterReminderCustom;

  /// No description provided for @waterReminderNotificationTitle.
  ///
  /// In bs, this message translates to:
  /// **'পানি খাওয়ার সময়'**
  String get waterReminderNotificationTitle;

  /// No description provided for @waterReminderNotificationBody.
  ///
  /// In bs, this message translates to:
  /// **'এক গ্লাস পানি খান'**
  String get waterReminderNotificationBody;

  /// No description provided for @waterReminderAddTitle.
  ///
  /// In bs, this message translates to:
  /// **'নতুন রিমাইন্ডার'**
  String get waterReminderAddTitle;

  /// No description provided for @waterReminderTime.
  ///
  /// In bs, this message translates to:
  /// **'সময়'**
  String get waterReminderTime;

  /// No description provided for @waterReminderDaily.
  ///
  /// In bs, this message translates to:
  /// **'প্রতিদিন'**
  String get waterReminderDaily;

  /// No description provided for @waterReminderDisabled.
  ///
  /// In bs, this message translates to:
  /// **'নিষ্ক্রিয়'**
  String get waterReminderDisabled;

  /// No description provided for @waterReminderNoReminders.
  ///
  /// In bs, this message translates to:
  /// **'কোনো রিমাইন্ডার নেই'**
  String get waterReminderNoReminders;

  /// No description provided for @waterReminderNoRemindersSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'সকাল, দুপুর ও সন্ধ্যায় পানি খাওয়ার রিমাইন্ডার যোগ করুন'**
  String get waterReminderNoRemindersSubtitle;

  /// No description provided for @waterReminderDeleted.
  ///
  /// In bs, this message translates to:
  /// **'রিমাইন্ডার মুছে ফেলা হয়েছে'**
  String get waterReminderDeleted;

  /// No description provided for @waterReminderSaved.
  ///
  /// In bs, this message translates to:
  /// **'রিমাইন্ডার সংরক্ষিত হয়েছে'**
  String get waterReminderSaved;

  /// No description provided for @waterReminderDays.
  ///
  /// In bs, this message translates to:
  /// **'সপ্তাহের দিন'**
  String get waterReminderDays;

  /// No description provided for @waterReminderDaysHint.
  ///
  /// In bs, this message translates to:
  /// **'কোনো দিন না বাছাই করলে প্রতিদিন চলবে'**
  String get waterReminderDaysHint;

  /// No description provided for @waterWeekdayMonday.
  ///
  /// In bs, this message translates to:
  /// **'সোম'**
  String get waterWeekdayMonday;

  /// No description provided for @waterWeekdayTuesday.
  ///
  /// In bs, this message translates to:
  /// **'মঙ্গল'**
  String get waterWeekdayTuesday;

  /// No description provided for @waterWeekdayWednesday.
  ///
  /// In bs, this message translates to:
  /// **'বুধ'**
  String get waterWeekdayWednesday;

  /// No description provided for @waterWeekdayThursday.
  ///
  /// In bs, this message translates to:
  /// **'বৃহস্পতি'**
  String get waterWeekdayThursday;

  /// No description provided for @waterWeekdayFriday.
  ///
  /// In bs, this message translates to:
  /// **'শুক্র'**
  String get waterWeekdayFriday;

  /// No description provided for @waterWeekdaySaturday.
  ///
  /// In bs, this message translates to:
  /// **'শনি'**
  String get waterWeekdaySaturday;

  /// No description provided for @waterWeekdaySunday.
  ///
  /// In bs, this message translates to:
  /// **'রবি'**
  String get waterWeekdaySunday;

  /// No description provided for @errorWaterNegative.
  ///
  /// In bs, this message translates to:
  /// **'অনুগ্রহ করে ০-এর বেশি পরিমাণ দিন'**
  String get errorWaterNegative;

  /// No description provided for @errorWaterUnrealistic.
  ///
  /// In bs, this message translates to:
  /// **'একবারে এত বেশি পানি যোগ করা যাবে না'**
  String get errorWaterUnrealistic;

  /// No description provided for @errorWaterGoalTooLow.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য কমপক্ষে ৫০০ মিলি হতে হবে'**
  String get errorWaterGoalTooLow;

  /// No description provided for @errorWaterGoalTooHigh.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য ১০০০০ মিলির বেশি হতে পারবে না'**
  String get errorWaterGoalTooHigh;

  /// No description provided for @dashboardCmUnit.
  ///
  /// In bs, this message translates to:
  /// **'সেমি'**
  String get dashboardCmUnit;

  /// No description provided for @weightTracker.
  ///
  /// In bs, this message translates to:
  /// **'ওজন ট্র্যাকার'**
  String get weightTracker;

  /// No description provided for @weightHistory.
  ///
  /// In bs, this message translates to:
  /// **'ওজনের ইতিহাস'**
  String get weightHistory;

  /// No description provided for @weightStatistics.
  ///
  /// In bs, this message translates to:
  /// **'ওজনের পরিসংখ্যান'**
  String get weightStatistics;

  /// No description provided for @weightCurrent.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান ওজন'**
  String get weightCurrent;

  /// No description provided for @weightSinceStart.
  ///
  /// In bs, this message translates to:
  /// **'শুরু থেকে'**
  String get weightSinceStart;

  /// No description provided for @weightGoalLabel.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য'**
  String get weightGoalLabel;

  /// No description provided for @weightGoalNotSet.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য নির্ধারিত নেই'**
  String get weightGoalNotSet;

  /// No description provided for @weightGoalReached.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য পূরণ হয়েছে'**
  String get weightGoalReached;

  /// No description provided for @weightRemainingLabel.
  ///
  /// In bs, this message translates to:
  /// **'বাকি'**
  String get weightRemainingLabel;

  /// No description provided for @weightTargetProgress.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্যের অগ্রগতি'**
  String get weightTargetProgress;

  /// No description provided for @weightBmi.
  ///
  /// In bs, this message translates to:
  /// **'BMI'**
  String get weightBmi;

  /// No description provided for @weightIdealWeight.
  ///
  /// In bs, this message translates to:
  /// **'আদর্শ ওজন'**
  String get weightIdealWeight;

  /// No description provided for @weightWeeklyChange.
  ///
  /// In bs, this message translates to:
  /// **'সাপ্তাহিক পরিবর্তন'**
  String get weightWeeklyChange;

  /// No description provided for @weightCalculators.
  ///
  /// In bs, this message translates to:
  /// **'ক্যালকুলেটর'**
  String get weightCalculators;

  /// No description provided for @weightBmr.
  ///
  /// In bs, this message translates to:
  /// **'BMR'**
  String get weightBmr;

  /// No description provided for @weightDailyCalories.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক ক্যালোরি'**
  String get weightDailyCalories;

  /// No description provided for @weightHealthyRange.
  ///
  /// In bs, this message translates to:
  /// **'স্বাস্থ্যকর পরিসর'**
  String get weightHealthyRange;

  /// No description provided for @weightNeedProfile.
  ///
  /// In bs, this message translates to:
  /// **'প্রোফাইল সম্পূর্ণ করুন'**
  String get weightNeedProfile;

  /// No description provided for @weightComposition.
  ///
  /// In bs, this message translates to:
  /// **'শারীরিক গঠন'**
  String get weightComposition;

  /// No description provided for @weightBodyFat.
  ///
  /// In bs, this message translates to:
  /// **'শরীরের চর্বি'**
  String get weightBodyFat;

  /// No description provided for @weightLeanMass.
  ///
  /// In bs, this message translates to:
  /// **'মাংসপেশির ভর'**
  String get weightLeanMass;

  /// No description provided for @weightBodyFatHint.
  ///
  /// In bs, this message translates to:
  /// **'গলা, কোমর ও নিতম্বের মাপ দিলে শরীরের চর্বির আরও নির্ভুল হিসাব পাওয়া যাবে।'**
  String get weightBodyFatHint;

  /// No description provided for @weightTrend.
  ///
  /// In bs, this message translates to:
  /// **'প্রবণতা'**
  String get weightTrend;

  /// No description provided for @weightHistoryDaily.
  ///
  /// In bs, this message translates to:
  /// **'দৈনিক'**
  String get weightHistoryDaily;

  /// No description provided for @weightHistoryWeekly.
  ///
  /// In bs, this message translates to:
  /// **'সাপ্তাহিক'**
  String get weightHistoryWeekly;

  /// No description provided for @weightHistoryMonthly.
  ///
  /// In bs, this message translates to:
  /// **'মাসিক'**
  String get weightHistoryMonthly;

  /// No description provided for @weightHistoryYearly.
  ///
  /// In bs, this message translates to:
  /// **'বার্ষিক'**
  String get weightHistoryYearly;

  /// No description provided for @weightNoHistory.
  ///
  /// In bs, this message translates to:
  /// **'কোনো তথ্য নেই'**
  String get weightNoHistory;

  /// No description provided for @weightNoHistorySubtitle.
  ///
  /// In bs, this message translates to:
  /// **'ওজন যোগ করলে এখানে ইতিহাস দেখতে পাবেন'**
  String get weightNoHistorySubtitle;

  /// No description provided for @weightEntries.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি'**
  String get weightEntries;

  /// No description provided for @weightLogTitle.
  ///
  /// In bs, this message translates to:
  /// **'ওজন যোগ করুন'**
  String get weightLogTitle;

  /// No description provided for @weightNoEntries.
  ///
  /// In bs, this message translates to:
  /// **'এখনো কোনো ওজন যোগ হয়নি'**
  String get weightNoEntries;

  /// No description provided for @weightNoEntriesSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'নিচের বোতাম থেকে ওজন যোগ করুন'**
  String get weightNoEntriesSubtitle;

  /// No description provided for @weightEditEntry.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি সম্পাদনা'**
  String get weightEditEntry;

  /// No description provided for @weightValue.
  ///
  /// In bs, this message translates to:
  /// **'ওজন'**
  String get weightValue;

  /// No description provided for @weightNote.
  ///
  /// In bs, this message translates to:
  /// **'নোট'**
  String get weightNote;

  /// No description provided for @weightLogSuccess.
  ///
  /// In bs, this message translates to:
  /// **'ওজন যোগ করা হয়েছে'**
  String get weightLogSuccess;

  /// No description provided for @weightLogUpdated.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি হালনাগাদ হয়েছে'**
  String get weightLogUpdated;

  /// No description provided for @weightLogDeleted.
  ///
  /// In bs, this message translates to:
  /// **'এন্ট্রি মুছে ফেলা হয়েছে'**
  String get weightLogDeleted;

  /// No description provided for @weightDeleteEntry.
  ///
  /// In bs, this message translates to:
  /// **'এই এন্ট্রি মুছবেন?'**
  String get weightDeleteEntry;

  /// No description provided for @weightDeleteEntryMessage.
  ///
  /// In bs, this message translates to:
  /// **'এই ওজনের এন্ট্রিটি মুছে ফেলা হবে।'**
  String get weightDeleteEntryMessage;

  /// No description provided for @weightGoalSheetTitle.
  ///
  /// In bs, this message translates to:
  /// **'ওজনের লক্ষ্য'**
  String get weightGoalSheetTitle;

  /// No description provided for @weightGoalSuggested.
  ///
  /// In bs, this message translates to:
  /// **'প্রস্তাবিত লক্ষ্য'**
  String get weightGoalSuggested;

  /// No description provided for @weightGoalSaved.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য সংরক্ষিত হয়েছে'**
  String get weightGoalSaved;

  /// No description provided for @errorWeightNegative.
  ///
  /// In bs, this message translates to:
  /// **'অনুগ্রহ করে ০-এর বেশি ওজন দিন'**
  String get errorWeightNegative;

  /// No description provided for @errorWeightUnrealistic.
  ///
  /// In bs, this message translates to:
  /// **'এই ওজন বাস্তবসম্মত নয়'**
  String get errorWeightUnrealistic;

  /// No description provided for @errorWeightGoalTooLow.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য কমপক্ষে ২০ কেজি হতে হবে'**
  String get errorWeightGoalTooLow;

  /// No description provided for @errorWeightGoalTooHigh.
  ///
  /// In bs, this message translates to:
  /// **'লক্ষ্য ৪০০ কেজির বেশি হতে পারবে না'**
  String get errorWeightGoalTooHigh;

  /// No description provided for @weightHistoryStart.
  ///
  /// In bs, this message translates to:
  /// **'শুরু'**
  String get weightHistoryStart;

  /// No description provided for @weightHistoryCurrent.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান'**
  String get weightHistoryCurrent;

  /// No description provided for @weightHistoryChange.
  ///
  /// In bs, this message translates to:
  /// **'পরিবর্তন'**
  String get weightHistoryChange;

  /// No description provided for @weightHistoryLogged.
  ///
  /// In bs, this message translates to:
  /// **'লগ হওয়া'**
  String get weightHistoryLogged;

  /// No description provided for @weightStatStart.
  ///
  /// In bs, this message translates to:
  /// **'শুরুর ওজন'**
  String get weightStatStart;

  /// No description provided for @weightStatCurrent.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান ওজন'**
  String get weightStatCurrent;

  /// No description provided for @weightStatMin.
  ///
  /// In bs, this message translates to:
  /// **'সর্বনিম্ন'**
  String get weightStatMin;

  /// No description provided for @weightStatMax.
  ///
  /// In bs, this message translates to:
  /// **'সর্বোচ্চ'**
  String get weightStatMax;

  /// No description provided for @weightStatAverage.
  ///
  /// In bs, this message translates to:
  /// **'গড়'**
  String get weightStatAverage;

  /// No description provided for @weightStatTotalChange.
  ///
  /// In bs, this message translates to:
  /// **'মোট পরিবর্তন'**
  String get weightStatTotalChange;

  /// No description provided for @weightStatDaysTracked.
  ///
  /// In bs, this message translates to:
  /// **'ট্র্যাক করা দিন'**
  String get weightStatDaysTracked;

  /// No description provided for @weightStatTotalEntries.
  ///
  /// In bs, this message translates to:
  /// **'মোট এন্ট্রি'**
  String get weightStatTotalEntries;

  /// No description provided for @weightStatCurrentStreak.
  ///
  /// In bs, this message translates to:
  /// **'বর্তমান ধারা'**
  String get weightStatCurrentStreak;

  /// No description provided for @weightStatLongestStreak.
  ///
  /// In bs, this message translates to:
  /// **'সর্বোচ্চ ধারা'**
  String get weightStatLongestStreak;

  /// No description provided for @weightStreakDays.
  ///
  /// In bs, this message translates to:
  /// **'{count} দিন'**
  String weightStreakDays(Object count);

  /// No description provided for @weightStatTrackedPeriod.
  ///
  /// In bs, this message translates to:
  /// **'ট্র্যাক করা সময়কাল'**
  String get weightStatTrackedPeriod;

  /// No description provided for @measurementAddTitle.
  ///
  /// In bs, this message translates to:
  /// **'মাপ যোগ করুন'**
  String get measurementAddTitle;

  /// No description provided for @measurementEditTitle.
  ///
  /// In bs, this message translates to:
  /// **'মাপ সম্পাদনা'**
  String get measurementEditTitle;

  /// No description provided for @measurementAddSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'সেন্টিমিটারে মাপ রেকর্ড করুন'**
  String get measurementAddSubtitle;

  /// No description provided for @measurementUpdated.
  ///
  /// In bs, this message translates to:
  /// **'মাপ হালনাগাদ হয়েছে'**
  String get measurementUpdated;

  /// No description provided for @measurementAdded.
  ///
  /// In bs, this message translates to:
  /// **'মাপ যোগ করা হয়েছে'**
  String get measurementAdded;

  /// No description provided for @measurementDeleted.
  ///
  /// In bs, this message translates to:
  /// **'মাপ মুছে ফেলা হয়েছে'**
  String get measurementDeleted;

  /// No description provided for @measurementDeleteTitle.
  ///
  /// In bs, this message translates to:
  /// **'এই মাপ মুছবেন?'**
  String get measurementDeleteTitle;

  /// No description provided for @measurementDeleteMessage.
  ///
  /// In bs, this message translates to:
  /// **'এই শারীরিক মাপের রেকর্ডটি মুছে ফেলা হবে।'**
  String get measurementDeleteMessage;

  /// No description provided for @measurementParts.
  ///
  /// In bs, this message translates to:
  /// **'টি মাপ'**
  String get measurementParts;

  /// No description provided for @measurementChest.
  ///
  /// In bs, this message translates to:
  /// **'বুক'**
  String get measurementChest;

  /// No description provided for @measurementWaist.
  ///
  /// In bs, this message translates to:
  /// **'কোমর'**
  String get measurementWaist;

  /// No description provided for @measurementHip.
  ///
  /// In bs, this message translates to:
  /// **'নিতম্ব'**
  String get measurementHip;

  /// No description provided for @measurementNeck.
  ///
  /// In bs, this message translates to:
  /// **'গলা'**
  String get measurementNeck;

  /// No description provided for @measurementLeftArm.
  ///
  /// In bs, this message translates to:
  /// **'বাম হাত'**
  String get measurementLeftArm;

  /// No description provided for @measurementRightArm.
  ///
  /// In bs, this message translates to:
  /// **'ডান হাত'**
  String get measurementRightArm;

  /// No description provided for @measurementLeftThigh.
  ///
  /// In bs, this message translates to:
  /// **'বাম উরু'**
  String get measurementLeftThigh;

  /// No description provided for @measurementRightThigh.
  ///
  /// In bs, this message translates to:
  /// **'ডান উরু'**
  String get measurementRightThigh;

  /// No description provided for @measurementLeftCalf.
  ///
  /// In bs, this message translates to:
  /// **'বাম কাফ'**
  String get measurementLeftCalf;

  /// No description provided for @measurementRightCalf.
  ///
  /// In bs, this message translates to:
  /// **'ডান কাফ'**
  String get measurementRightCalf;

  /// No description provided for @errorMeasurementInvalid.
  ///
  /// In bs, this message translates to:
  /// **'অনুগ্রহ করে ০-এর বেশি মান দিন'**
  String get errorMeasurementInvalid;

  /// No description provided for @errorMeasurementEmpty.
  ///
  /// In bs, this message translates to:
  /// **'কমপক্ষে একটি মাপ দিন'**
  String get errorMeasurementEmpty;

  /// No description provided for @measurementHistory.
  ///
  /// In bs, this message translates to:
  /// **'ইতিহাস'**
  String get measurementHistory;

  /// No description provided for @measurementNoMeasurements.
  ///
  /// In bs, this message translates to:
  /// **'কোনো মাপ নেই'**
  String get measurementNoMeasurements;

  /// No description provided for @measurementNoMeasurementsSubtitle.
  ///
  /// In bs, this message translates to:
  /// **'ট্র্যাকিং শুরু করতে আপনার প্রথম শারীরিক মাপ যোগ করুন'**
  String get measurementNoMeasurementsSubtitle;

  /// No description provided for @measurementTrend.
  ///
  /// In bs, this message translates to:
  /// **'মাপের প্রবণতা'**
  String get measurementTrend;

  /// No description provided for @measurementTrendEmpty.
  ///
  /// In bs, this message translates to:
  /// **'এই অংশের জন্য এখনো কোনো মাপ নেই'**
  String get measurementTrendEmpty;

  /// No description provided for @bodyMeasurementTitle.
  ///
  /// In bs, this message translates to:
  /// **'শারীরিক মাপ'**
  String get bodyMeasurementTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bs':
      return AppLocalizationsBs();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
