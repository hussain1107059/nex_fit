// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NexFit';

  @override
  String get appTagline => 'Start your fitness journey today';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonViewAll => 'View all';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonProfile => 'Profile';

  @override
  String get commonLanguage => 'Language';

  @override
  String get commonTheme => 'Theme';

  @override
  String get commonNotification => 'Notifications';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonWeek => 'Week';

  @override
  String get commonMonth => 'Month';

  @override
  String get commonYear => 'Year';

  @override
  String get tabHome => 'Home';

  @override
  String get tabWorkout => 'Workout';

  @override
  String get tabDiet => 'Diet';

  @override
  String get tabProgress => 'Progress';

  @override
  String get tabNutrition => 'Nutrition';

  @override
  String get tabProfile => 'Profile';

  @override
  String get moduleWorkoutSubtitle => 'Plan and track your workouts here.';

  @override
  String get moduleProgressSubtitle => 'See your progress and statistics here.';

  @override
  String get moduleNutritionSubtitle => 'Manage your meals and nutrition here.';

  @override
  String get moduleProfileSubtitle => 'Your account and settings live here.';

  @override
  String get emptyNoData => 'No data yet';

  @override
  String get emptyNoDataSubtitle =>
      'Add your first entry and it will appear here.';

  @override
  String get emptyNoResults => 'No results found';

  @override
  String get emptyNoResultsSubtitle => 'Try searching for something else.';

  @override
  String get emptyNoInternet => 'No internet connection';

  @override
  String get emptyNoInternetSubtitle => 'Reconnect and try again.';

  @override
  String get errorSomethingWentWrong => 'Something went wrong';

  @override
  String get errorSomethingWentWrongSubtitle =>
      'An unexpected error occurred. Please try again.';

  @override
  String get errorNoInternet => 'No internet connection';

  @override
  String get errorNoInternetSubtitle =>
      'Please check your internet connection.';

  @override
  String get errorTimeout => 'Request timed out';

  @override
  String get errorTimeoutSubtitle =>
      'The request took too long. Please try again.';

  @override
  String get errorPermissionDenied => 'Permission denied';

  @override
  String get errorPermissionDeniedSubtitle =>
      'You don\'t have permission to perform this action.';

  @override
  String get errorNetwork => 'Network error';

  @override
  String get errorServer => 'Server error';

  @override
  String get errorServerSubtitle =>
      'Could not reach the server. Please try again later.';

  @override
  String get errorDatabase => 'Database error';

  @override
  String get errorDatabaseSubtitle =>
      'Unable to read data from the local database.';

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String get authSignInTitle => 'Welcome back';

  @override
  String get authSignInSubtitle => 'Sign in to your account';

  @override
  String get authSignUpTitle => 'Create a new account';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authSignOut => 'Sign Out';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authEmailRequired => 'Email is required';

  @override
  String get authEmailInvalid => 'Enter a valid email address';

  @override
  String get authPasswordRequired => 'Password is required';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authName => 'Name';

  @override
  String get authNameRequired => 'Name is required';

  @override
  String get authUnavailable =>
      'Authentication is unavailable right now. Please try again later.';

  @override
  String get authCancelled => 'Sign in cancelled';

  @override
  String get authGoogleSignInFailed => 'Google sign in failed';

  @override
  String get authGoogleSignInConfig =>
      'Google sign in is not configured. Add the Google server client ID (--dart-define=GOOGLE_SIGN_IN_SERVER_CLIENT_ID) and make sure the Firebase project supports the Google provider.';

  @override
  String get authUserNotFound => 'No account found for this email';

  @override
  String get authWrongPassword => 'Incorrect password';

  @override
  String get authEmailInUse => 'This email is already in use';

  @override
  String get authUserDisabled => 'This account has been disabled';

  @override
  String get authTooManyRequests =>
      'Too many attempts. Please try again later.';

  @override
  String get authOperationNotAllowed => 'This operation is not allowed';

  @override
  String get authAccountExistsWithDifferentCredential =>
      'An account already exists with this email. Try signing in.';

  @override
  String get authGeneric => 'Unable to sign in. Please try again.';

  @override
  String get authBusy => 'Please wait...';

  @override
  String get authOrContinueWith => 'or continue with';

  @override
  String get authRememberMe => 'Remember me';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authNameHint => 'Your full name';

  @override
  String get authSignUpSubtitle => 'Create a new account and get started';

  @override
  String get authPasswordWeak =>
      'Password is not strong enough. Use uppercase, lowercase, number and symbol';

  @override
  String get authPasswordStrengthWeak => 'Weak';

  @override
  String get authPasswordStrengthMedium => 'Medium';

  @override
  String get authPasswordStrengthStrong => 'Strong';

  @override
  String get authEmailVerificationTitle => 'Verify your email';

  @override
  String get authEmailVerificationSubtitle =>
      'Confirm your email address before continuing';

  @override
  String get authEmailVerificationSentTo => 'We sent a verification link to';

  @override
  String get authEmailNotVerified => 'Email not verified';

  @override
  String get authResendEmail => 'Resend verification email';

  @override
  String get authRefreshStatus => 'I\'ve verified, refresh status';

  @override
  String get authVerificationSent => 'Verification email sent';

  @override
  String get authVerificationNotYet =>
      'Your email is not verified yet. Open the link from your inbox first';

  @override
  String get authEmailVerified => 'Email verified';

  @override
  String get authEmailVerificationFailed => 'Could not send verification email';

  @override
  String get authAccountCreated => 'Account created!';

  @override
  String get authAccountCreatedSubtitle =>
      'Your account is ready. We sent a verification link to your email';

  @override
  String get authForgotPasswordTitle => 'Forgot password';

  @override
  String get authForgotPasswordSubtitle =>
      'Enter your email and we\'ll send you a reset link';

  @override
  String get authSendResetLink => 'Send reset link';

  @override
  String get authResetLinkSent => 'Reset link sent!';

  @override
  String get authResetLinkSentSubtitle =>
      'Check your inbox or spam folder and follow the link';

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String get authSignOutConfirmTitle => 'Sign out?';

  @override
  String get authSignOutConfirmMessage => 'Are you sure you want to sign out?';

  @override
  String get dashboardTemporaryTitle => 'Temporary Dashboard';

  @override
  String get dashboardTemporarySubtitle =>
      'This is a temporary screen. The real Dashboard will be built next';

  @override
  String get dashboardMemberSince => 'Member since';

  @override
  String get dashboardLastLogin => 'Last login';

  @override
  String get connectivityOnline => 'You are back online';

  @override
  String get connectivityOffline => 'You are offline';

  @override
  String get connectivityBackOnline => 'Connection restored';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get splashLoading => 'Preparing NexFit...';

  @override
  String get backupTitle => 'Backup & Restore';

  @override
  String get backupLastBackup => 'Last backup';

  @override
  String get backupNever => 'Never';

  @override
  String get backupUploading => 'Uploading backup...';

  @override
  String get backupRestoring => 'Restoring...';

  @override
  String get backupSuccess => 'Backup completed successfully';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get backupDriveDisconnected => 'Google Drive not connected';

  @override
  String get backupNotFound => 'Backup not found';

  @override
  String get backupCorrupted => 'The backup file is corrupted';

  @override
  String get dashboardGreetingMorning => 'Good morning';

  @override
  String get dashboardGreetingAfternoon => 'Good afternoon';

  @override
  String get dashboardGreetingEvening => 'Good evening';

  @override
  String get dashboardTodayOverview => 'Today\'s overview';

  @override
  String get dashboardCaloriesBurned => 'Calories burned';

  @override
  String get dashboardWater => 'Water';

  @override
  String get dashboardSteps => 'Steps';

  @override
  String get dashboardWeight => 'Weight';

  @override
  String get dashboardBmi => 'BMI';

  @override
  String get dashboardStreak => 'Streak';

  @override
  String get dashboardQuickActions => 'Quick actions';

  @override
  String get dashboardStartWorkout => 'Start workout';

  @override
  String get dashboardLogWater => 'Log water';

  @override
  String get dashboardAddMeal => 'Add meal';

  @override
  String get dashboardLogWeight => 'Log weight';

  @override
  String get dashboardBmiCalculator => 'BMI calculator';

  @override
  String get dashboardSleepTracker => 'Sleep tracker';

  @override
  String get dashboardTodaysGoal => 'Today\'s goal';

  @override
  String get dashboardWorkoutMinutes => 'Workout (min)';

  @override
  String get dashboardCalories => 'Calories';

  @override
  String get dashboardRecentActivity => 'Recent activity';

  @override
  String get dashboardNoActivity => 'No activity yet';

  @override
  String get dashboardNoActivitySubtitle => 'Your activity will appear here.';

  @override
  String get dashboardNoWorkoutYet => 'No workout yet';

  @override
  String get dashboardNoWorkoutYetSubtitle =>
      'Start your first workout and build strength today!';

  @override
  String get dashboardFirstWorkout => 'First workout';

  @override
  String get dashboardNoWeightYet => 'No weight logged';

  @override
  String get dashboardNoWeightYetSubtitle =>
      'Log your weight today to track your progress.';

  @override
  String get dashboardNoBadgeYet => 'No badge yet';

  @override
  String get dashboardMotivation => 'Motivation';

  @override
  String get dashboardAchievements => 'Achievements';

  @override
  String get dashboardCurrentStreak => 'Current streak';

  @override
  String get dashboardDays => 'days';

  @override
  String get dashboardUpcomingReminders => 'Today\'s reminders';

  @override
  String get dashboardNoReminders => 'No reminders today';

  @override
  String get dashboardNoRemindersSubtitle =>
      'Check settings to add a new reminder.';

  @override
  String get dashboardWeeklyStats => 'Weekly stats';

  @override
  String get dashboardNoDataWeek => 'No data this week';

  @override
  String get dashboardNoWeightData => 'No weight this week';

  @override
  String get dashboardGoalNotSet => 'No goal set';

  @override
  String get dashboardComingSoon => 'This module is coming soon';

  @override
  String get dashboardLogWaterTitle => 'Log water';

  @override
  String get dashboardLogWaterHint => 'Select amount (ml)';

  @override
  String get dashboardLogWaterSuccess => 'Water logged';

  @override
  String get dashboardLogWeightTitle => 'Log weight';

  @override
  String get dashboardLogWeightHint => 'Weight (kg)';

  @override
  String get dashboardLogWeightSuccess => 'Weight logged';

  @override
  String get dashboardBmiTitle => 'BMI calculator';

  @override
  String get dashboardHeightCm => 'Height (cm)';

  @override
  String get dashboardWeightKg => 'Weight (kg)';

  @override
  String get dashboardBmiResult => 'BMI';

  @override
  String get dashboardBmiSaved => 'BMI saved';

  @override
  String get dashboardSearchHint => 'Search workouts, foods, exercises...';

  @override
  String get dashboardSearchWorkouts => 'Workouts';

  @override
  String get dashboardSearchExercises => 'Exercises';

  @override
  String get dashboardSearchFoods => 'Foods';

  @override
  String get dashboardSearchMeals => 'Meals';

  @override
  String get dashboardLoadError => 'Could not load dashboard';

  @override
  String get dashboardActivityWorkout => 'Workout';

  @override
  String get dashboardActivityWater => 'Water';

  @override
  String get dashboardActivityMeal => 'Meal';

  @override
  String get dashboardActivityWeight => 'Weight';

  @override
  String get dashboardActivitySleep => 'Sleep';

  @override
  String get dashboardMinutesShort => 'min';

  @override
  String get dashboardHoursShort => 'h';

  @override
  String get dashboardMlUnit => 'ml';

  @override
  String get dashboardKgUnit => 'kg';

  @override
  String get dashboardKcalUnit => 'kcal';

  @override
  String get dashboardEarnedOn => 'Earned on';

  @override
  String get bmiUnderweight => 'Underweight';

  @override
  String get bmiNormal => 'Normal';

  @override
  String get bmiOverweight => 'Overweight';

  @override
  String get bmiObese => 'Obese';

  @override
  String get dialogConfirmTitle => 'Are you sure?';

  @override
  String get dialogExitApp => 'Do you want to exit the app?';

  @override
  String get dialogDiscardChanges => 'Do you want to discard your changes?';

  @override
  String get exitAppHint => 'Press back again to exit';

  @override
  String get formFieldRequired => 'This field is required';

  @override
  String get formFieldTooShort => 'Value is too short';

  @override
  String get formFieldTooLong => 'Value is too long';

  @override
  String get formFieldInvalid => 'Value is invalid';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileMemberSince => 'Member since';

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileCompleteProfile => 'Complete your profile';

  @override
  String get profileCompleteProfileSubtitle =>
      'Add your physical details to unlock BMI, BMR and daily targets.';

  @override
  String get profilePhysicalInfo => 'Physical info';

  @override
  String get profileAge => 'Age';

  @override
  String get profileYears => 'yrs';

  @override
  String get profileGender => 'Gender';

  @override
  String get profileHeight => 'Height';

  @override
  String get profileCurrentWeight => 'Current weight';

  @override
  String get profileTargetWeight => 'Target weight';

  @override
  String get profileFitnessGoal => 'Fitness goal';

  @override
  String get profileActivityLevel => 'Activity level';

  @override
  String get profileBmi => 'BMI';

  @override
  String get profileBmiValue => 'Your BMI';

  @override
  String get profileBmiCategory => 'Category';

  @override
  String get profileHealthyRange => 'Healthy range';

  @override
  String get profileSuggestion => 'Suggestion';

  @override
  String get profileBmr => 'BMR';

  @override
  String get profileDailyCalories => 'Daily calories';

  @override
  String get profileDailyCaloriesTarget => 'Daily calories target';

  @override
  String get profileDailyWaterTarget => 'Daily water target';

  @override
  String get profileDailyStepTarget => 'Daily step target';

  @override
  String get profileDailyTargets => 'Daily targets';

  @override
  String get profileStatistics => 'Statistics';

  @override
  String get profileTotalWorkouts => 'Total workouts';

  @override
  String get profileCurrentStreak => 'Current streak';

  @override
  String get profileLongestStreak => 'Longest streak';

  @override
  String get profileCaloriesBurned => 'Calories burned';

  @override
  String get profileWaterIntake => 'Water intake';

  @override
  String get profileWeightLost => 'Weight lost';

  @override
  String get profileDays => 'days';

  @override
  String get profileNotSet => 'Not set';

  @override
  String get profileIncomplete => 'Complete your profile to see this';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsBackupRestore => 'Backup & restore';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsComingSoon => 'This feature is coming soon';

  @override
  String get settingsLastBackup => 'Last backup';

  @override
  String get settingsNever => 'Never';

  @override
  String get settingsAboutTitle => 'About NexFit';

  @override
  String get settingsAboutMessage =>
      'NexFit is a premium, offline-first fitness companion that tracks your workouts, nutrition, body metrics and daily progress.';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get editName => 'Name';

  @override
  String get editNameHint => 'Your full name';

  @override
  String get editDateOfBirth => 'Date of birth';

  @override
  String get editCountry => 'Country';

  @override
  String get editCountryHint => 'Your country';

  @override
  String get editLanguage => 'Language';

  @override
  String get editLanguageBangla => 'Bangla';

  @override
  String get editLanguageEnglish => 'English';

  @override
  String get editHeightCm => 'Height (cm)';

  @override
  String get editWeightKg => 'Weight (kg)';

  @override
  String get editTargetWeightKg => 'Target weight (kg)';

  @override
  String get editProfilePhoto => 'Profile photo';

  @override
  String get editChangePhoto => 'Change photo';

  @override
  String get editTakePhoto => 'Take a photo';

  @override
  String get editChooseFromGallery => 'Choose from gallery';

  @override
  String get editRemovePhoto => 'Remove photo';

  @override
  String get editProfileSaved => 'Profile updated';

  @override
  String get editProfileSavedSubtitle => 'Your profile has been updated.';

  @override
  String get editSelectGender => 'Select gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get goalWeightLoss => 'Weight Loss';

  @override
  String get goalWeightGain => 'Weight Gain';

  @override
  String get goalMaintainWeight => 'Maintain Weight';

  @override
  String get goalMuscleGain => 'Muscle Gain';

  @override
  String get goalGeneralFitness => 'General Fitness';

  @override
  String get activitySedentary => 'Sedentary';

  @override
  String get activityLight => 'Lightly Active';

  @override
  String get activityModerate => 'Moderately Active';

  @override
  String get activityVeryActive => 'Very Active';

  @override
  String get activityAthlete => 'Athlete';

  @override
  String get providerEmail => 'Email';

  @override
  String get providerGoogle => 'Google';

  @override
  String get bmiSuggestionUnderweight =>
      'Consider a calorie surplus with strength training to reach a healthy weight.';

  @override
  String get bmiSuggestionNormal =>
      'Great job! Maintain your weight with a balanced diet and regular activity.';

  @override
  String get bmiSuggestionOverweight =>
      'A calorie deficit with regular cardio can help you reach a healthy weight.';

  @override
  String get bmiSuggestionObese =>
      'Consult a health professional and follow a gradual weight-loss plan.';

  @override
  String get profileNameRequired => 'Name is required';

  @override
  String get profileHeightInvalid => 'Enter a height between 60 and 250 cm';

  @override
  String get profileWeightInvalid => 'Enter a weight between 20 and 400 kg';

  @override
  String get profileTargetWeightInvalid =>
      'Enter a target weight between 20 and 400 kg';

  @override
  String get profileBirthInvalid => 'Choose a valid date of birth';

  @override
  String get profileCountryInvalid => 'Country name is too long';

  @override
  String get profilePhotoChanged => 'Profile photo updated';

  @override
  String get profilePhotoRemoved => 'Profile photo removed';

  @override
  String get profilePhotoError => 'Could not update profile photo';

  @override
  String get commonClear => 'Clear';

  @override
  String get workoutHistory => 'Workout history';

  @override
  String get workoutSearchHint => 'Search workouts, exercises...';

  @override
  String get workoutSearchTitle => 'Search workouts';

  @override
  String get workoutSearchEmptyTitle => 'Search the library';

  @override
  String get workoutSearchEmptySubtitle =>
      'Type a keyword or apply filters to find the perfect workout.';

  @override
  String get workoutRecommended => 'Recommended for you';

  @override
  String get workoutPopular => 'Popular workouts';

  @override
  String get workoutRecent => 'Recently completed';

  @override
  String get workoutFavorites => 'Favourites';

  @override
  String get workoutEmptyTitle => 'No workouts yet';

  @override
  String get workoutEmptySubtitle => 'Your workout library will appear here.';

  @override
  String get workoutContinueTitle => 'Continue workout';

  @override
  String get workoutResume => 'Resume';

  @override
  String get workoutExercises => 'exercises';

  @override
  String get workoutExercise => 'Exercise';

  @override
  String get workoutRoutine => 'Routine';

  @override
  String get workoutAbout => 'About this workout';

  @override
  String get workoutMuscles => 'Muscles worked';

  @override
  String get workoutEquipment => 'Equipment needed';

  @override
  String get workoutStartNow => 'Start workout';

  @override
  String get workoutGetReady => 'Get ready';

  @override
  String get workoutGetReadySubtitle => 'Your workout is about to begin';

  @override
  String get workoutDifficultyBeginner => 'Beginner';

  @override
  String get workoutDifficultyIntermediate => 'Intermediate';

  @override
  String get workoutDifficultyAdvanced => 'Advanced';

  @override
  String get workoutSets => 'sets';

  @override
  String get workoutReps => 'reps';

  @override
  String get workoutSeconds => 'sec';

  @override
  String get workoutTimed => 'Timed';

  @override
  String get workoutRest => 'rest';

  @override
  String get workoutRestTitle => 'Rest';

  @override
  String get workoutRestTime => 'Rest time';

  @override
  String get workoutSkipRest => 'Skip rest';

  @override
  String get workoutEndRest => 'End rest';

  @override
  String get workoutComplete => 'Complete';

  @override
  String get workoutFinish => 'All done!';

  @override
  String get workoutExitTitle => 'Leave workout?';

  @override
  String get workoutExitMessage =>
      'Your progress will be saved and you can resume it later.';

  @override
  String get workoutExit => 'Leave';

  @override
  String get workoutDuration => 'Duration';

  @override
  String get workoutCaloriesBurned => 'Calories burned';

  @override
  String get workoutTotalWorkouts => 'workouts';

  @override
  String get workoutNoHistory => 'No workouts yet';

  @override
  String get workoutNoHistorySubtitle =>
      'Complete a workout and it will show up here.';

  @override
  String get workoutCompleteTitle => 'Workout complete!';

  @override
  String get workoutCompleteSubtitle => 'Great job! Keep the momentum going.';

  @override
  String get workoutNewAchievements => 'Achievements unlocked';

  @override
  String get workoutDone => 'Done';

  @override
  String get workoutFilterAll => 'All';

  @override
  String get workoutFilterDifficulty => 'Level';

  @override
  String get workoutFilterDuration => 'Duration';

  @override
  String get workoutFilterShort => 'Short (<20 min)';

  @override
  String get workoutFilterMedium => 'Medium (20-40 min)';

  @override
  String get workoutFilterLong => 'Long (40+ min)';

  @override
  String get workoutFilterGoal => 'Goal';

  @override
  String get workoutFilterEquipment => 'Equipment';

  @override
  String get workoutClearFilters => 'Clear filters';

  @override
  String get exerciseLibrary => 'Exercise Library';

  @override
  String get exerciseLibrarySubtitle => 'Browse exercises by muscle group';

  @override
  String get exerciseSearchHint => 'Search exercises...';

  @override
  String get exerciseSearchTitle => 'Search exercises';

  @override
  String get exerciseSearchEmptyTitle => 'Search the exercise library';

  @override
  String get exerciseSearchEmptySubtitle =>
      'Type a keyword or filter by category, level or equipment.';

  @override
  String get exerciseAll => 'All';

  @override
  String get exerciseFavorites => 'Favourites';

  @override
  String get exerciseFavoritesOnly => 'Favourites only';

  @override
  String get exerciseNoFavorites => 'No favourites yet';

  @override
  String get exerciseNoFavoritesSubtitle =>
      'Tap the heart on any exercise to save it here.';

  @override
  String get exerciseNoResults => 'No exercises found';

  @override
  String get exerciseNoResultsSubtitle => 'Try a different search or filter.';

  @override
  String get exerciseTargetMuscle => 'Target muscle';

  @override
  String get exerciseSecondaryMuscle => 'Secondary muscles';

  @override
  String get exerciseHowTo => 'How to do it';

  @override
  String get exerciseTips => 'Tips';

  @override
  String get exerciseCommonMistakes => 'Common mistakes';

  @override
  String get exerciseSafety => 'Safety notes';

  @override
  String get exerciseAbout => 'About this exercise';

  @override
  String get exerciseStart => 'Start exercise';

  @override
  String get exerciseSets => 'sets';

  @override
  String get exerciseReps => 'reps';

  @override
  String get exerciseRest => 'rest';

  @override
  String exerciseSetOf(Object current, Object total) {
    return 'Set $current of $total';
  }

  @override
  String get exerciseNextUp => 'Next up';

  @override
  String get exerciseCompleteTitle => 'Exercise complete!';

  @override
  String get exerciseCompleteSubtitle => 'Great job! Keep pushing.';

  @override
  String get exerciseCaloriesEstimate => 'Calories';

  @override
  String get exerciseDuration => 'Duration';

  @override
  String get exerciseAllCategories => 'All categories';

  @override
  String get workoutSummary => 'Workout summary';

  @override
  String get workoutSummaryBadges => 'Badges earned';

  @override
  String get workoutSummaryStreak => 'Current streak';

  @override
  String get workoutSummaryCompletion => 'Completion';

  @override
  String get workoutSummaryMotivation => 'Every rep counts. Keep going!';

  @override
  String workoutSummaryExercisesDone(Object completed, Object total) {
    return '$completed of $total exercises done';
  }

  @override
  String get workoutSummaryDays => 'day(s)';

  @override
  String get foodCategoryRice => 'Rice';

  @override
  String get foodCategoryBread => 'Bread';

  @override
  String get foodCategoryMeat => 'Meat';

  @override
  String get foodCategoryChicken => 'Chicken';

  @override
  String get foodCategoryFish => 'Fish';

  @override
  String get foodCategoryEgg => 'Egg';

  @override
  String get foodCategoryVegetables => 'Vegetables';

  @override
  String get foodCategoryFruits => 'Fruits';

  @override
  String get foodCategoryMilk => 'Milk';

  @override
  String get foodCategoryDairy => 'Dairy';

  @override
  String get foodCategoryFastFood => 'Fast Food';

  @override
  String get foodCategoryDessert => 'Desserts';

  @override
  String get foodCategoryDrinks => 'Drinks';

  @override
  String get foodCategoryNuts => 'Nuts';

  @override
  String get foodCategorySeeds => 'Seeds';

  @override
  String get foodCategoryHealthySnacks => 'Healthy Snacks';

  @override
  String get nutritionKcal => 'kcal';

  @override
  String get nutritionMacros => 'Macros';

  @override
  String get nutritionProtein => 'Protein';

  @override
  String get nutritionCarbs => 'Carbs';

  @override
  String get nutritionFat => 'Fat';

  @override
  String get nutritionRemaining => 'Remaining';

  @override
  String get nutritionGoalMet => 'Goal on track';

  @override
  String get nutritionGoalProgress => 'Building progress';

  @override
  String get nutritionWaterIntake => 'Water intake';

  @override
  String get nutritionWaterHint => 'Tracked from the water module';

  @override
  String get nutritionMeals => 'Meals';

  @override
  String get nutritionMealEmpty => 'No food added yet';

  @override
  String get nutritionItems => 'items';

  @override
  String get nutritionNoFoodLogged => 'Nothing logged for this meal yet.';

  @override
  String get nutritionAddFood => 'Add food';

  @override
  String get nutritionAddToMeal => 'Add to meal';

  @override
  String get nutritionAddToLog => 'Add to log';

  @override
  String get nutritionMealType => 'Meal';

  @override
  String get nutritionQuantity => 'Quantity';

  @override
  String get nutritionCalories => 'Calories';

  @override
  String get nutritionSelectMeal => 'Choose a meal slot first';

  @override
  String get nutritionFoodAdded => 'Food added';

  @override
  String get nutritionEditQuantity => 'Edit quantity';

  @override
  String get nutritionRemoveFood => 'Remove food';

  @override
  String get nutritionRemoveFoodMessage => 'Remove this food from your log?';

  @override
  String get nutritionDuplicate => 'Duplicate';

  @override
  String get nutritionCopyYesterday => 'Copy yesterday';

  @override
  String nutritionCopyYesterdayDone(Object count) {
    return '$count items copied from yesterday';
  }

  @override
  String get nutritionDaysAgo => 'days ago';

  @override
  String get nutritionDaysLater => 'days later';

  @override
  String get nutritionDaysShort => 'days';

  @override
  String get nutritionMacroTracker => 'Macro tracker';

  @override
  String get nutritionHistory => 'Nutrition history';

  @override
  String get nutritionAvgMacros => 'Average macros';

  @override
  String get nutritionAvgCalories => 'Avg kcal';

  @override
  String get nutritionAvgWater => 'Avg water';

  @override
  String get nutritionLoggedDays => 'Logged days';

  @override
  String get nutritionCalorieTrend => 'Calorie trend';

  @override
  String get nutritionGoalAdherence => 'Goal adherence';

  @override
  String get nutritionDailyBreakdown => 'Daily breakdown';

  @override
  String get nutritionNoHistory => 'No data for this period';

  @override
  String get nutritionNoHistorySubtitle =>
      'Log your meals and your history will appear here.';

  @override
  String get nutritionFoodDatabase => 'Food database';

  @override
  String get nutritionFoodSearchHint => 'Search foods...';

  @override
  String get nutritionAllFoods => 'All foods';

  @override
  String get nutritionFavorites => 'Favorites';

  @override
  String get nutritionRecent => 'Recent';

  @override
  String get nutritionFrequent => 'Frequent';

  @override
  String get nutritionNoResults => 'No foods found';

  @override
  String get nutritionNoResultsSubtitle => 'Try a different search or filter.';

  @override
  String get nutritionNoFavorites => 'No favorites yet';

  @override
  String get nutritionNoFavoritesSubtitle =>
      'Tap the heart on any food to save it here.';

  @override
  String get nutritionNoRecent => 'No recent foods';

  @override
  String get nutritionNoRecentSubtitle => 'Foods you log will appear here.';

  @override
  String get nutritionNoFrequent => 'No frequent foods yet';

  @override
  String get nutritionNoFrequentSubtitle =>
      'Foods you log often will appear here.';

  @override
  String get nutritionNutritionFacts => 'Nutrition facts';

  @override
  String get nutritionServingSize => 'Serving size';

  @override
  String get nutritionFiber => 'Fiber';

  @override
  String get nutritionSugar => 'Sugar';

  @override
  String get nutritionSodium => 'Sodium';

  @override
  String get nutritionPotassium => 'Potassium';

  @override
  String get nutritionCalcium => 'Calcium';

  @override
  String get nutritionIron => 'Iron';

  @override
  String get nutritionVitaminA => 'Vitamin A';

  @override
  String get nutritionVitaminC => 'Vitamin C';

  @override
  String get nutritionWaterContent => 'Water content';

  @override
  String get nutritionMealPlanner => 'Meal planner';

  @override
  String get nutritionNewTemplate => 'New template';

  @override
  String get nutritionNoTemplates => 'No meal templates yet';

  @override
  String get nutritionNoTemplatesSubtitle =>
      'Save your favourite meals and log them in one tap.';

  @override
  String get nutritionSaveTemplate => 'Save template';

  @override
  String get nutritionTemplateName => 'Template name';

  @override
  String get nutritionTemplateNameHint => 'e.g. Post-workout meal';

  @override
  String get nutritionTemplateNameRequired => 'Enter a template name';

  @override
  String get nutritionTemplateNoFoods => 'No foods selected yet';

  @override
  String nutritionSelectedFoods(Object count) {
    return '$count foods selected';
  }

  @override
  String get nutritionTemplateSaved => 'Template saved';

  @override
  String get nutritionTemplateLogged => 'Template logged';

  @override
  String get nutritionTemplateDeleted => 'Template deleted';

  @override
  String get nutritionLogTemplate => 'Log template';

  @override
  String get nutritionDeleteTemplate => 'Delete template?';

  @override
  String nutritionDeleteTemplateMessage(Object name) {
    return 'Delete \'$name\'? This can\'t be undone.';
  }

  @override
  String get waterTitle => 'Water';

  @override
  String get waterTracker => 'Water tracker';

  @override
  String get waterHistory => 'Water history';

  @override
  String get waterStatistics => 'Statistics';

  @override
  String get waterReminders => 'Reminders';

  @override
  String get waterHydration => 'Hydration';

  @override
  String get waterIntakeToday => 'Today\'s water';

  @override
  String get waterDailyGoal => 'Daily goal';

  @override
  String get waterRemaining => 'Remaining';

  @override
  String get waterGoalProgress => 'Goal progress';

  @override
  String get waterQuickAdd => 'Quick add';

  @override
  String get waterCustomAmount => 'Custom amount';

  @override
  String get waterNote => 'Note (optional)';

  @override
  String get waterLogSuccess => 'Water added';

  @override
  String get waterLogUpdated => 'Entry updated';

  @override
  String get waterLogDeleted => 'Entry deleted';

  @override
  String get waterEntries => 'Entries';

  @override
  String get waterNoEntries => 'No water logged today';

  @override
  String get waterNoEntriesSubtitle => 'Add water using the buttons below';

  @override
  String get waterSetGoal => 'Set goal';

  @override
  String get waterEditGoal => 'Edit goal';

  @override
  String get waterGoalSheetTitle => 'Daily water goal';

  @override
  String get waterGoalSuggested => 'Suggested goals';

  @override
  String get waterGoalSaved => 'Goal saved';

  @override
  String get waterStatusNeedsWater => 'Drink more water';

  @override
  String get waterStatusGettingThere => 'Getting there';

  @override
  String get waterStatusNearlyThere => 'Almost there';

  @override
  String get waterStatusGoalMet => 'Goal met';

  @override
  String get waterStatusExceeded => 'Goal exceeded';

  @override
  String get waterEditEntry => 'Edit entry';

  @override
  String get waterDeleteEntry => 'Delete this entry?';

  @override
  String get waterDeleteEntryMessage => 'This water entry will be deleted.';

  @override
  String get waterHistoryDaily => 'Daily';

  @override
  String get waterHistoryWeekly => 'Weekly';

  @override
  String get waterHistoryMonthly => 'Monthly';

  @override
  String get waterHistoryYearly => 'Yearly';

  @override
  String get waterHistoryTotal => 'Total';

  @override
  String get waterHistoryAverage => 'Average';

  @override
  String get waterHistoryBest => 'Best';

  @override
  String get waterHistoryLogged => 'Logged';

  @override
  String get waterNoHistory => 'No data yet';

  @override
  String get waterNoHistorySubtitle =>
      'Your history will appear here once you start logging water.';

  @override
  String get waterStatAvgDaily => 'Avg daily intake';

  @override
  String get waterStatBestDay => 'Best day';

  @override
  String get waterStatCurrentStreak => 'Current streak';

  @override
  String get waterStatLongestStreak => 'Longest streak';

  @override
  String get waterStatTotalConsumed => 'Total consumed';

  @override
  String get waterStatTotalEntries => 'Total entries';

  @override
  String get waterStatTrackedDays => 'Tracked days';

  @override
  String waterStreakDays(Object count) {
    return '$count days';
  }

  @override
  String get waterReminderMorning => 'Morning reminder';

  @override
  String get waterReminderAfternoon => 'Afternoon reminder';

  @override
  String get waterReminderEvening => 'Evening reminder';

  @override
  String get waterReminderCustom => 'Custom reminder';

  @override
  String get waterReminderNotificationTitle => 'Time to hydrate';

  @override
  String get waterReminderNotificationBody => 'Drink a glass of water';

  @override
  String get waterReminderAddTitle => 'New reminder';

  @override
  String get waterReminderTime => 'Time';

  @override
  String get waterReminderDaily => 'Daily';

  @override
  String get waterReminderDisabled => 'Disabled';

  @override
  String get waterReminderNoReminders => 'No reminders yet';

  @override
  String get waterReminderNoRemindersSubtitle =>
      'Add morning, afternoon and evening hydration reminders';

  @override
  String get waterReminderDeleted => 'Reminder deleted';

  @override
  String get waterReminderSaved => 'Reminder saved';

  @override
  String get waterReminderDays => 'Days of week';

  @override
  String get waterReminderDaysHint => 'Leave unselected to run every day';

  @override
  String get waterWeekdayMonday => 'Mon';

  @override
  String get waterWeekdayTuesday => 'Tue';

  @override
  String get waterWeekdayWednesday => 'Wed';

  @override
  String get waterWeekdayThursday => 'Thu';

  @override
  String get waterWeekdayFriday => 'Fri';

  @override
  String get waterWeekdaySaturday => 'Sat';

  @override
  String get waterWeekdaySunday => 'Sun';

  @override
  String get errorWaterNegative => 'Enter an amount greater than 0';

  @override
  String get errorWaterUnrealistic => 'That\'s too much for a single entry';

  @override
  String get errorWaterGoalTooLow => 'Goal must be at least 500 ml';

  @override
  String get errorWaterGoalTooHigh => 'Goal cannot exceed 10000 ml';

  @override
  String get dashboardCmUnit => 'cm';

  @override
  String get weightTracker => 'Weight Tracker';

  @override
  String get weightHistory => 'Weight History';

  @override
  String get weightStatistics => 'Weight Statistics';

  @override
  String get weightCurrent => 'Current weight';

  @override
  String get weightSinceStart => 'since start';

  @override
  String get weightGoalLabel => 'Goal';

  @override
  String get weightGoalNotSet => 'Goal not set';

  @override
  String get weightGoalReached => 'Goal reached';

  @override
  String get weightRemainingLabel => 'to goal';

  @override
  String get weightTargetProgress => 'progress to goal';

  @override
  String get weightBmi => 'BMI';

  @override
  String get weightIdealWeight => 'Ideal weight';

  @override
  String get weightWeeklyChange => 'Weekly change';

  @override
  String get weightCalculators => 'Calculators';

  @override
  String get weightBmr => 'BMR';

  @override
  String get weightDailyCalories => 'Daily calories';

  @override
  String get weightHealthyRange => 'Healthy range';

  @override
  String get weightNeedProfile => 'Complete your profile';

  @override
  String get weightComposition => 'Body composition';

  @override
  String get weightBodyFat => 'Body fat';

  @override
  String get weightLeanMass => 'Lean mass';

  @override
  String get weightBodyFatHint =>
      'Adding neck, waist and hip measurements gives a more accurate body fat estimate.';

  @override
  String get weightTrend => 'Trend';

  @override
  String get weightHistoryDaily => 'Daily';

  @override
  String get weightHistoryWeekly => 'Weekly';

  @override
  String get weightHistoryMonthly => 'Monthly';

  @override
  String get weightHistoryYearly => 'Yearly';

  @override
  String get weightNoHistory => 'No data yet';

  @override
  String get weightNoHistorySubtitle =>
      'Your weight history will appear here once you start logging.';

  @override
  String get weightEntries => 'Entries';

  @override
  String get weightLogTitle => 'Log weight';

  @override
  String get weightNoEntries => 'No weight logged yet';

  @override
  String get weightNoEntriesSubtitle =>
      'Log your weight using the button below';

  @override
  String get weightEditEntry => 'Edit entry';

  @override
  String get weightValue => 'Weight';

  @override
  String get weightNote => 'Note';

  @override
  String get weightLogSuccess => 'Weight logged';

  @override
  String get weightLogUpdated => 'Entry updated';

  @override
  String get weightLogDeleted => 'Entry deleted';

  @override
  String get weightDeleteEntry => 'Delete this entry?';

  @override
  String get weightDeleteEntryMessage => 'This weight entry will be deleted.';

  @override
  String get weightGoalSheetTitle => 'Weight goal';

  @override
  String get weightGoalSuggested => 'Suggested goals';

  @override
  String get weightGoalSaved => 'Goal saved';

  @override
  String get errorWeightNegative => 'Enter a weight greater than 0';

  @override
  String get errorWeightUnrealistic => 'That weight is not realistic';

  @override
  String get errorWeightGoalTooLow => 'Goal must be at least 20 kg';

  @override
  String get errorWeightGoalTooHigh => 'Goal cannot exceed 400 kg';

  @override
  String get weightHistoryStart => 'Start';

  @override
  String get weightHistoryCurrent => 'Current';

  @override
  String get weightHistoryChange => 'Change';

  @override
  String get weightHistoryLogged => 'Logged';

  @override
  String get weightStatStart => 'Start weight';

  @override
  String get weightStatCurrent => 'Current weight';

  @override
  String get weightStatMin => 'Minimum';

  @override
  String get weightStatMax => 'Maximum';

  @override
  String get weightStatAverage => 'Average';

  @override
  String get weightStatTotalChange => 'Total change';

  @override
  String get weightStatDaysTracked => 'Tracked days';

  @override
  String get weightStatTotalEntries => 'Total entries';

  @override
  String get weightStatCurrentStreak => 'Current streak';

  @override
  String get weightStatLongestStreak => 'Longest streak';

  @override
  String weightStreakDays(Object count) {
    return '$count days';
  }

  @override
  String get weightStatTrackedPeriod => 'Tracked period';

  @override
  String get measurementAddTitle => 'Add measurement';

  @override
  String get measurementEditTitle => 'Edit measurement';

  @override
  String get measurementAddSubtitle => 'Record circumferences in centimetres';

  @override
  String get measurementUpdated => 'Measurement updated';

  @override
  String get measurementAdded => 'Measurement added';

  @override
  String get measurementDeleted => 'Measurement deleted';

  @override
  String get measurementDeleteTitle => 'Delete this measurement?';

  @override
  String get measurementDeleteMessage =>
      'This body measurement record will be deleted.';

  @override
  String get measurementParts => 'parts';

  @override
  String get measurementChest => 'Chest';

  @override
  String get measurementWaist => 'Waist';

  @override
  String get measurementHip => 'Hip';

  @override
  String get measurementNeck => 'Neck';

  @override
  String get measurementLeftArm => 'Left arm';

  @override
  String get measurementRightArm => 'Right arm';

  @override
  String get measurementLeftThigh => 'Left thigh';

  @override
  String get measurementRightThigh => 'Right thigh';

  @override
  String get measurementLeftCalf => 'Left calf';

  @override
  String get measurementRightCalf => 'Right calf';

  @override
  String get errorMeasurementInvalid => 'Enter a value greater than 0';

  @override
  String get errorMeasurementEmpty => 'Enter at least one measurement';

  @override
  String get measurementHistory => 'History';

  @override
  String get measurementNoMeasurements => 'No measurements yet';

  @override
  String get measurementNoMeasurementsSubtitle =>
      'Add your first body measurement to start tracking';

  @override
  String get measurementTrend => 'Measurement trend';

  @override
  String get measurementTrendEmpty =>
      'No measurements recorded for this part yet';

  @override
  String get bodyMeasurementTitle => 'Body Measurements';

  @override
  String get progressTitle => 'Progress & Analytics';

  @override
  String get progressFilterToday => 'Today';

  @override
  String get progressFilterLast7Days => '7 days';

  @override
  String get progressFilterLast30Days => '30 days';

  @override
  String get progressFilterLast90Days => '90 days';

  @override
  String get progressFilterThisYear => 'This year';

  @override
  String get progressFilterCustom => 'Custom';

  @override
  String get progressSelectRange => 'Pick date range';

  @override
  String get progressScore => 'Score';

  @override
  String get progressCompletion => 'Complete';

  @override
  String get progressGoalNotSet => 'Goal not set';

  @override
  String get progressDaysLeft => 'Days left:';

  @override
  String get progressGoalWeight => 'Weight';

  @override
  String get progressGoalWorkout => 'Workouts';

  @override
  String get progressGoalCalories => 'Calories';

  @override
  String get progressGoalWater => 'Water';

  @override
  String get progressGoalSteps => 'Steps';

  @override
  String get progressGoalSleep => 'Sleep';

  @override
  String get progressRecordLongestWorkout => 'Longest workout';

  @override
  String get progressRecordHighestCalories => 'Highest calories burned';

  @override
  String get progressRecordFastestWorkout => 'Fastest workout';

  @override
  String get progressRecordLongestStreak => 'Longest streak';

  @override
  String get progressRecordBestWeek => 'Best week';

  @override
  String get progressRecordBestMonth => 'Best month';

  @override
  String get progressRecordMostActiveDay => 'Most active day';

  @override
  String get progressOnDate => 'On';

  @override
  String get progressWeekOf => 'Week of';

  @override
  String get progressUnitKcal => 'kcal';

  @override
  String get progressUnitKg => 'kg';

  @override
  String get progressUnitMl => 'ml';

  @override
  String get progressUnitMin => 'min';

  @override
  String get progressUnitDays => 'days';

  @override
  String get progressUnitSteps => 'steps';

  @override
  String get progressUnitWorkouts => 'workouts';

  @override
  String get progressUnitHours => 'hrs';

  @override
  String get progressSummaryWorkouts => 'Workouts';

  @override
  String get progressSummaryCaloriesBurned => 'Calories burned';

  @override
  String get progressSummaryActiveDays => 'Active days';

  @override
  String get progressSummaryAvgSteps => 'Avg steps';

  @override
  String get progressSummaryAvgWater => 'Avg water';

  @override
  String get progressSummaryAvgSleep => 'Avg sleep';

  @override
  String get progressSummaryCaloriesConsumed => 'Calories eaten';

  @override
  String get progressSummaryWeightChange => 'Weight change';

  @override
  String get progressChartCalories => 'Calories burned';

  @override
  String get progressChartWater => 'Water (ml)';

  @override
  String get progressChartSteps => 'Steps';

  @override
  String get progressChartSleep => 'Sleep (hrs)';

  @override
  String get progressChartWeight => 'Weight (kg)';

  @override
  String get progressChartWorkoutMinutes => 'Workout time (min)';

  @override
  String get progressChartBmi => 'BMI';

  @override
  String get progressChartWorkoutCount => 'Workouts';

  @override
  String get progressGoals => 'Goals';

  @override
  String get progressRecords => 'Personal records';

  @override
  String get progressScoreTitle => 'Fitness Score';

  @override
  String get progressFullReport => 'Full report';

  @override
  String get progressExport => 'Export report';

  @override
  String get progressExportTitle => 'Export report';

  @override
  String get progressExportSubtitle => 'Save and share your report';

  @override
  String get progressExportCsv => 'CSV file';

  @override
  String get progressExportPdf => 'PDF file';

  @override
  String get progressExportExcel => 'Excel file';

  @override
  String get progressExporting => 'Generating report...';

  @override
  String get progressExported => 'Report generated';

  @override
  String get progressExportFailed => 'Could not generate report';

  @override
  String get progressEmptyTitle => 'No data yet';

  @override
  String get progressEmptySubtitle =>
      'No tracking data in this period. Log a workout, water or weight to get started.';

  @override
  String get progressMetricWorkout => 'Workout';

  @override
  String get progressMetricConsistency => 'Consistency';

  @override
  String get progressMetricActivity => 'Activity';

  @override
  String get progressMetricHydration => 'Hydration';

  @override
  String get progressMetricSleep => 'Sleep';

  @override
  String get progressMetricNutrition => 'Nutrition';

  @override
  String get progressScoreExcellent => 'Excellent';

  @override
  String get progressScoreGood => 'Good';

  @override
  String get progressScoreFair => 'Fair';

  @override
  String get progressScoreNeedsWork => 'Needs work';

  @override
  String get progressScoreGettingStarted => 'Getting started';

  @override
  String get progressAvgPerDay => 'Avg/day';

  @override
  String get progressTotal => 'Total';

  @override
  String get progressReportTitle => 'Progress report';

  @override
  String get progressRecordsTitle => 'Personal records';

  @override
  String get progressGoalsTitle => 'Goal progress';

  @override
  String get progressScoreBreakdown => 'Score breakdown';

  @override
  String get progressPeriodLabel => 'Period';

  @override
  String get progressNoRecords => 'No records yet';

  @override
  String get progressNoRecordsSubtitle =>
      'Your personal records will appear here once you start tracking.';

  @override
  String get progressCalorieBalance => 'Calorie balance';

  @override
  String get reminderTypeWorkout => 'Workout';

  @override
  String get reminderTypeWater => 'Water';

  @override
  String get reminderTypeMeal => 'Meal';

  @override
  String get reminderTypeWeight => 'Weight';

  @override
  String get reminderTypeSleep => 'Sleep';

  @override
  String get reminderTypeMedicine => 'Medicine';

  @override
  String get reminderTypeStep => 'Steps';

  @override
  String get reminderTypeCustom => 'Custom';

  @override
  String get reminderScheduleOneTime => 'One time';

  @override
  String get reminderScheduleDaily => 'Daily';

  @override
  String get reminderScheduleWeekly => 'Weekly';

  @override
  String get reminderScheduleMonthly => 'Monthly';

  @override
  String get reminderScheduleCustomDays => 'Custom days';

  @override
  String get reminderEveryDay => 'Every day';

  @override
  String get reminderEveryMonth => 'Every month';

  @override
  String reminderDayOfMonth(Object day) {
    return 'Day $day of the month';
  }

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersAdd => 'Add';

  @override
  String get remindersEdit => 'Edit reminder';

  @override
  String get remindersCreate => 'Create reminder';

  @override
  String get remindersSettings => 'Settings';

  @override
  String get remindersStatistics => 'Statistics';

  @override
  String get remindersHistory => 'History';

  @override
  String get remindersAll => 'All';

  @override
  String get remindersTodayLabel => 'Today';

  @override
  String get remindersUpcomingLabel => 'Upcoming';

  @override
  String remindersCount(Object count) {
    return '$count reminders';
  }

  @override
  String remindersToday(Object count) {
    return '$count today';
  }

  @override
  String remindersUpcoming(Object count) {
    return '$count upcoming';
  }

  @override
  String get remindersSmartSuggestions => 'Smart suggestions';

  @override
  String get remindersEmpty => 'No reminders';

  @override
  String get remindersEmptySubtitle =>
      'Create a reminder and it will appear here.';

  @override
  String get remindersComplete => 'Complete';

  @override
  String get remindersSkip => 'Skip';

  @override
  String get remindersDuplicate => 'Duplicate';

  @override
  String get remindersMarkedComplete => 'Marked as complete';

  @override
  String get remindersMarkedSkipped => 'Marked as skipped';

  @override
  String get remindersDuplicated => 'Reminder duplicated';

  @override
  String get remindersDeleted => 'Reminder deleted';

  @override
  String get remindersHistoryEmpty => 'No history yet';

  @override
  String get remindersHistoryEmptySubtitle =>
      'Your reminder history will appear here.';

  @override
  String get remindersCompleted => 'Completed';

  @override
  String get remindersMissed => 'Missed';

  @override
  String get remindersSkipped => 'Skipped';

  @override
  String get remindersTitleField => 'Title';

  @override
  String get remindersDescription => 'Description';

  @override
  String get remindersType => 'Type';

  @override
  String get remindersRepeat => 'Repeat';

  @override
  String get remindersTime => 'Time';

  @override
  String get remindersDate => 'Date';

  @override
  String get remindersDays => 'Days';

  @override
  String get remindersDayOfMonthLabel => 'Day of month';

  @override
  String get remindersNotification => 'Notification';

  @override
  String get remindersSound => 'Sound';

  @override
  String get remindersVibration => 'Vibration';

  @override
  String get remindersSilent => 'Silent';

  @override
  String get remindersActionButtons => 'Action buttons';

  @override
  String get remindersActionButtonsSubtitle =>
      'Show Complete and Skip buttons on the notification.';

  @override
  String get remindersAddTime => 'Add time';

  @override
  String get remindersMaxTimes => 'You can add up to 5 times per day.';

  @override
  String get remindersErrorNoTime => 'Pick at least one time.';

  @override
  String get remindersErrorNoDays => 'Pick at least one day.';

  @override
  String get remindersErrorNoDate => 'Pick a date.';

  @override
  String get remindersSaved => 'Reminder saved';

  @override
  String get remindersSettingsSubtitle =>
      'Control how reminder notifications behave on this device.';

  @override
  String get remindersSoundSubtitle => 'Play a sound when a reminder fires.';

  @override
  String get remindersVibrationSubtitle => 'Vibrate when a reminder fires.';

  @override
  String get remindersSilentSubtitle =>
      'Mute sound and vibration for all reminders.';

  @override
  String get remindersTimeFormat => 'Time format';

  @override
  String get remindersTimeFormat12h => '12 hour (AM/PM)';

  @override
  String get remindersTimeFormat24h => '24 hour';

  @override
  String get remindersCompletionRate => 'Completion rate';

  @override
  String get remindersMissedRate => 'Missed rate';

  @override
  String get remindersTotal => 'Total';

  @override
  String get remindersMostSuccessful => 'Most successful reminder';

  @override
  String get remindersNoData => 'No data yet';

  @override
  String remindersCompletedCount(Object count) {
    return '$count completed';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAllSettings => 'All Settings';

  @override
  String get settingsEditProfile => 'Edit Profile';

  @override
  String get settingsUnits => 'Units';

  @override
  String get settingsUnitsMetric => 'Metric';

  @override
  String get settingsUnitsImperial => 'Imperial';

  @override
  String get settingsWeekStart => 'Week starts on';

  @override
  String get settingsWeekStartsSunday => 'Sunday';

  @override
  String get settingsWeekStartsMonday => 'Monday';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsDynamicColor => 'Dynamic color';

  @override
  String get settingsDynamicColorSubtitle =>
      'Use the system\'s Material You colors';

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsFontSizeSmall => 'Small';

  @override
  String get settingsFontSizeMedium => 'Medium';

  @override
  String get settingsFontSizeLarge => 'Large';

  @override
  String get settingsFontSizeExtraLarge => 'Extra large';

  @override
  String get settingsLanguageSubtitle =>
      'Choose the app language. Changes apply instantly.';

  @override
  String get settingsNotificationsMasterSubtitle =>
      'Turn all notifications on or off';

  @override
  String get settingsNotificationPreferences => 'Notification preferences';

  @override
  String get settingsNotificationBehaviour => 'Behavior';

  @override
  String get settingsNotificationSound => 'Sound';

  @override
  String get settingsNotificationVibration => 'Vibration';

  @override
  String get settingsReminderCategories => 'Reminder categories';

  @override
  String get settingsReminderCategoriesSubtitle =>
      'These preferences are used as defaults when creating new reminders.';

  @override
  String get settingsReminderWorkout => 'Workout reminders';

  @override
  String get settingsReminderMeal => 'Meal reminders';

  @override
  String get settingsReminderWater => 'Water reminders';

  @override
  String get settingsReminderWeight => 'Weight reminders';

  @override
  String get settingsReminderSleep => 'Sleep reminders';

  @override
  String get settingsReminderChallenge => 'Challenge reminders';

  @override
  String get settingsReminderAchievement => 'Achievement reminders';

  @override
  String get settingsWorkout => 'Workout';

  @override
  String get settingsWorkoutSubtitle => 'Default workout player behavior';

  @override
  String get settingsWorkoutTiming => 'Timing';

  @override
  String get settingsDefaultRestTime => 'Default rest time';

  @override
  String settingsRestSeconds(Object seconds) {
    return '$seconds seconds';
  }

  @override
  String get settingsWorkoutBehaviour => 'Behavior';

  @override
  String get settingsAutoStartTimer => 'Auto-start timer';

  @override
  String get settingsCountdownVoice => 'Countdown voice';

  @override
  String get settingsExerciseAnimation => 'Exercise animation';

  @override
  String get settingsAutoNextExercise => 'Auto-next exercise';

  @override
  String get settingsNutritionGoals => 'Daily goals';

  @override
  String get settingsNutrition => 'Nutrition';

  @override
  String get settingsNutritionSubtitle =>
      'Set your daily calorie and macro targets.';

  @override
  String get settingsDailyCalories => 'Daily calories';

  @override
  String get settingsProtein => 'Protein';

  @override
  String get settingsCarbs => 'Carbs';

  @override
  String get settingsFat => 'Fat';

  @override
  String get settingsWater => 'Daily water';

  @override
  String get settingsGramUnit => 'g';

  @override
  String settingsMl(Object ml) {
    return '$ml ml';
  }

  @override
  String get settingsGoalHint => 'Enter a goal';

  @override
  String get settingsPrivacySensitive => 'Sensitive content';

  @override
  String get settingsHideRecentApps => 'Hide from recent apps';

  @override
  String get settingsHideRecentAppsSubtitle =>
      'Hide the app preview in the app switcher';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get settingsDeleteLocalData => 'Delete local data';

  @override
  String get settingsDeleteLocalDataSubtitle =>
      'Erase all local records on this device';

  @override
  String get settingsDeleteLocalDataConfirm =>
      'All your local data will be permanently deleted. This cannot be undone.';

  @override
  String get settingsDeleteLocalDataAction => 'Delete';

  @override
  String get settingsDeleteLocalDataDone => 'Local data deleted';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsSecuritySubtitle => 'App lock, PIN and biometrics';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsSupport => 'Support';

  @override
  String get settingsDeveloper => 'Developer options';

  @override
  String get settingsDeveloperSubtitle => 'Debug and testing tools';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockSubtitle => 'Require a PIN to open the app';

  @override
  String get settingsChangePin => 'Change PIN';

  @override
  String get settingsBiometric => 'Biometrics';

  @override
  String get settingsBiometricUnlock => 'Biometric unlock';

  @override
  String get settingsBiometricSubtitle =>
      'Use fingerprint/face instead of the PIN';

  @override
  String get settingsAutoLock => 'Auto-lock';

  @override
  String get settingsAutoLockImmediately => 'Immediately';

  @override
  String get settingsAutoLockMinutes1 => 'After 1 minute';

  @override
  String get settingsAutoLockMinutes5 => 'After 5 minutes';

  @override
  String get settingsAutoLockMinutes15 => 'After 15 minutes';

  @override
  String get settingsAutoLockMinutes30 => 'After 30 minutes';

  @override
  String get settingsPinLock => 'PIN';

  @override
  String get settingsPinCurrent => 'Enter current PIN';

  @override
  String get settingsPinCurrentSubtitle =>
      'Verify your current PIN to continue';

  @override
  String get settingsPinSetupTitle => 'Set a new PIN';

  @override
  String get settingsPinSetupSubtitle => 'Choose a 4-digit PIN';

  @override
  String get settingsPinConfirm => 'Confirm your PIN';

  @override
  String get settingsPinConfirmSubtitle => 'Enter the PIN again to confirm';

  @override
  String get settingsPinIncorrect => 'Incorrect PIN';

  @override
  String get settingsPinMismatch => 'PINs do not match, try again';

  @override
  String get settingsLockTitle => 'NexFit is locked';

  @override
  String get settingsLockSubtitle => 'Enter your PIN to continue';

  @override
  String get settingsStorageUsage => 'Usage';

  @override
  String get settingsDatabaseSize => 'Database size';

  @override
  String get settingsImageCacheSize => 'Image cache size';

  @override
  String get settingsCalculating => 'Calculating...';

  @override
  String get settingsStorageActions => 'Maintenance';

  @override
  String get settingsClearImageCache => 'Clear image cache';

  @override
  String get settingsOptimizeDatabase => 'Optimize database';

  @override
  String get settingsOptimizeDatabaseSubtitle =>
      'Reclaims unused space and improves performance';

  @override
  String get settingsOptimizeDatabaseConfirm => 'Run a database optimization?';

  @override
  String get settingsOptimizeDatabaseAction => 'Optimize';

  @override
  String get settingsOptimizeDatabaseDone => 'Database optimized';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String get settingsAutoBackup => 'Automatic backup';

  @override
  String get settingsAutoBackupSubtitle =>
      'Create local backups as your data changes';

  @override
  String get settingsDataSync => 'Data sync';

  @override
  String get settingsDataSyncSubtitle => 'Sync data across devices';

  @override
  String get settingsBackupNow => 'Back up now';

  @override
  String get settingsBackupFailed => 'Backup failed';

  @override
  String get settingsBackupSuccess => 'Backup complete';

  @override
  String get settingsBackupSuccessMessage =>
      'A copy of your data was saved to the app\'s documents folder.';

  @override
  String get settingsHelpCenter => 'Help center';

  @override
  String get settingsContactSupport => 'Contact support';

  @override
  String get settingsContactSubject => 'NexFit support needed';

  @override
  String get settingsReportProblem => 'Report a problem';

  @override
  String get settingsReportSubject => 'NexFit problem report';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsTerms => 'Terms of service';

  @override
  String get settingsLinkFailed => 'Could not open the link';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Permanently delete your account and all data';

  @override
  String get settingsDeleteAccountConfirm =>
      'Are you sure? This permanently deletes your account and all data.';

  @override
  String get settingsDeleteAccountAction => 'Delete account';

  @override
  String get settingsDeleteAccountFailed => 'Could not delete your account';

  @override
  String get settingsDeveloperLogging => 'Logging';

  @override
  String get settingsDebugLogging => 'Debug logging';

  @override
  String get settingsDebugLoggingSubtitle => 'Record detailed logs';

  @override
  String get settingsDeveloperInfo => 'Info';

  @override
  String get settingsDbVersion => 'Database version';

  @override
  String get settingsDeveloperReset => 'Reset';

  @override
  String get settingsResetAll => 'Reset all settings';

  @override
  String get settingsResetAllSubtitle => 'Restore default values';

  @override
  String get settingsResetAllConfirm =>
      'All settings will be restored to their default values. Continue?';

  @override
  String get settingsResetAllAction => 'Reset';

  @override
  String get settingsResetAllDone => 'All settings reset';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsDriveConnected => 'Connected';

  @override
  String get settingsDriveDisconnected => 'Not connected';

  @override
  String get settingsConnectDrive => 'Connect Google Drive';

  @override
  String get settingsConnectingDrive => 'Connecting...';

  @override
  String get settingsBackupSchedule => 'Backup schedule';

  @override
  String get settingsScheduleManual => 'Manual';

  @override
  String get settingsScheduleDaily => 'Daily';

  @override
  String get settingsScheduleWeekly => 'Weekly';

  @override
  String get settingsScheduleMonthly => 'Monthly';

  @override
  String get settingsBackupRetention => 'Backup retention';

  @override
  String get settingsBackupRetentionSubtitle =>
      'Maximum number of backups to keep';

  @override
  String get settingsBackupOnWifiOnly => 'Wi-Fi only';

  @override
  String get settingsBackupOnWifiOnlySubtitle =>
      'Take automatic backups only on Wi-Fi';

  @override
  String get settingsBackupWhileCharging => 'While charging';

  @override
  String get settingsBackupWhileChargingSubtitle =>
      'Take automatic backups only while charging';

  @override
  String get settingsRemoteBackups => 'Cloud backups';

  @override
  String get settingsNoRemoteBackups => 'No cloud backups yet';

  @override
  String get settingsRestore => 'Restore';

  @override
  String get settingsRestoreBackup => 'Restore backup';

  @override
  String get settingsRestoreConfirm =>
      'Restore data from this backup? Your current data will be replaced.';

  @override
  String get settingsRestoreWarningNewer =>
      'Warning: your data has changed since this backup. Restoring will lose recent changes.';

  @override
  String get settingsRestoreWarningOlder =>
      'This backup was created by an older app version. Your data will be upgraded after restoring.';

  @override
  String get settingsRestoreBlockedNewer =>
      'This backup was created by a newer app version and cannot be restored.';

  @override
  String get settingsRestoreSuccess => 'Data restored';

  @override
  String get settingsRestoreFailed => 'Restore failed';

  @override
  String get settingsDeleteBackup => 'Delete backup';

  @override
  String get settingsDeleteBackupConfirm => 'Delete this backup?';

  @override
  String get settingsBackupDeleteSuccess => 'Backup deleted';

  @override
  String get settingsSignOutDrive => 'Sign out of Drive';

  @override
  String get settingsSignOutDriveSubtitle =>
      'Saved backups will not be deleted';

  @override
  String get settingsBackupProgressUploading => 'Uploading backup...';

  @override
  String get settingsBackupProgressRestoring => 'Restoring data...';

  @override
  String get settingsBackupAuto => 'Automatic';

  @override
  String get settingsBackupManual => 'Manual';

  @override
  String get settingsBackupEncrypted => 'Encrypted';

  @override
  String get settingsBackupSize => 'Size';

  @override
  String get settingsBackupDevice => 'Device';

  @override
  String get settingsBackupStatusSuccess => 'Successful';

  @override
  String get settingsBackupStatusFailed => 'Failed';

  @override
  String get settingsBackupStatusInProgress => 'In progress';

  @override
  String get backupNoInternet => 'No internet connection';

  @override
  String get backupSnapshotFailed => 'Could not create a database snapshot';

  @override
  String get backupFromNewerVersion =>
      'This backup was created by a newer app version';

  @override
  String get backupNoUser => 'Sign in is required to back up';

  @override
  String get backupNotNexFit => 'The file is not a valid NexFit backup';

  @override
  String get backupVersionUnsupported => 'Backup format not supported';

  @override
  String get backupNotSupportedOnWeb => 'Restore is not supported on web';

  @override
  String get backupDecryptFailed => 'Could not decrypt the backup';

  @override
  String get backupInvalidKey => 'Backup key is invalid';

  @override
  String get dashboardSystemHealth => 'System health';

  @override
  String get healthSync => 'Sync';

  @override
  String get healthSecurity => 'Security';

  @override
  String get healthSecurityLocked => 'Locked';

  @override
  String get healthSecurityOpen => 'Open';

  @override
  String get healthDatabase => 'Database';

  @override
  String get healthBackup => 'Backup';

  @override
  String get healthLastSync => 'Last sync';

  @override
  String get healthDatabaseError => 'Error';

  @override
  String get settingsSyncStatus => 'Sync status';

  @override
  String get settingsSyncInProgress => 'Syncing...';

  @override
  String get settingsSyncNever => 'Never synced';

  @override
  String get settingsSyncPending => 'pending';

  @override
  String get settingsSyncHealthy => 'All up to date';

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String get settingsScreenshotLock => 'Screenshot lock';

  @override
  String get settingsScreenshotLockSubtitle =>
      'Block screenshots and screen recording';

  @override
  String get settingsSessionTimeout => 'Session timeout';

  @override
  String settingsSessionTimeoutMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String settingsSessionTimeoutHours(int hours) {
    return '$hours hours';
  }

  @override
  String get settingsEncryption => 'Data encryption';

  @override
  String get settingsEncryptionSubtitle => 'Encrypt sensitive data at rest';

  @override
  String get settingsRunOptimization => 'Run database optimization';

  @override
  String get settingsRunOptimizationSubtitle =>
      'Vacuum, clear caches and prune old logs';

  @override
  String get settingsOptimizationDone => 'Optimization complete';
}
