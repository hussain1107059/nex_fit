import '../../l10n/app_localizations.dart';

/// Resolves a `Failure.message` translation key to a localized string.
///
/// Failure messages produced by the use cases are keys (e.g. `authWrongPassword`,
/// `errorNetwork`, `connectivityOffline`). This maps those keys to the
/// generated [AppLocalizations] getters. Unknown keys fall back to
/// [AppLocalizations.errorUnknown].
String localizeFailureMessage(AppLocalizations l10n, String message) {
  return switch (message) {
    'errorNetwork' => l10n.errorNetwork,
    'errorServer' => l10n.errorServer,
    'errorTimeout' => l10n.errorTimeout,
    'errorDatabase' => l10n.errorDatabase,
    'errorPermissionDenied' => l10n.errorPermissionDenied,
    'errorUnknown' => l10n.errorUnknown,
    'connectivityOffline' => l10n.connectivityOffline,
    'connectivityOnline' => l10n.connectivityOnline,
    'connectivityBackOnline' => l10n.connectivityBackOnline,
    'authBusy' => l10n.authBusy,
    'authUnavailable' => l10n.authUnavailable,
    'authCancelled' => l10n.authCancelled,
    'authGoogleSignInFailed' => l10n.authGoogleSignInFailed,
    'authUserNotFound' => l10n.authUserNotFound,
    'authWrongPassword' => l10n.authWrongPassword,
    'authEmailInvalid' => l10n.authEmailInvalid,
    'authEmailInUse' => l10n.authEmailInUse,
    'authPasswordTooShort' => l10n.authPasswordTooShort,
    'authUserDisabled' => l10n.authUserDisabled,
    'authTooManyRequests' => l10n.authTooManyRequests,
    'authOperationNotAllowed' => l10n.authOperationNotAllowed,
    'authAccountExistsWithDifferentCredential' =>
      l10n.authAccountExistsWithDifferentCredential,
    'authGeneric' => l10n.authGeneric,
    'authEmailVerificationFailed' => l10n.authEmailVerificationFailed,
    'backupFailed' => l10n.backupFailed,
    'backupDriveDisconnected' => l10n.backupDriveDisconnected,
    'backupNotFound' => l10n.backupNotFound,
    'backupCorrupted' => l10n.backupCorrupted,
    'backupNoInternet' => l10n.backupNoInternet,
    'backupSnapshotFailed' => l10n.backupSnapshotFailed,
    'backupFromNewerVersion' => l10n.backupFromNewerVersion,
    'backupNoUser' => l10n.backupNoUser,
    'backupNotNexFit' => l10n.backupNotNexFit,
    'backupVersionUnsupported' => l10n.backupVersionUnsupported,
    'backupNotSupportedOnWeb' => l10n.backupNotSupportedOnWeb,
    'backupDecryptFailed' => l10n.backupDecryptFailed,
    'backupInvalidKey' => l10n.backupInvalidKey,
    'errorNoInternet' => l10n.errorNoInternet,
    _ => l10n.errorUnknown,
  };
}
