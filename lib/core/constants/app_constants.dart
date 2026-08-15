class AppConstants {
  AppConstants._();

  static const String appName = 'NexFit';
  static const String appTagline = 'Start your fitness journey today';
  static const String appVersion = '1.0.0';

  static const String databaseName = 'nexfit.db';
  static const int databaseVersion = 18;

  static const Duration splashDuration = Duration(milliseconds: 900);
  static const Duration debounceDuration = Duration(milliseconds: 400);
  static const Duration animationDuration = Duration(milliseconds: 280);

  static const int maxNameLength = 60;
  static const int maxPasswordLength = 64;
  static const int minPasswordLength = 6;
  static const int strongPasswordLength = 8;

  static const String defaultLocale = 'bn';
  static const String fallbackLocale = 'en';

  static const double desktopBreakpoint = 900;
  static const double tabletBreakpoint = 600;

  // ---------------------------------------------------------------------
  // Google Drive backup
  // ---------------------------------------------------------------------
  static const String backupMagic = 'NXFBK001';
  static const int backupFormatVersion = 1;
  static const int backupDefaultRetention = 5;
  static const int backupMaxRetention = 20;
  static const String backupKeyStorageKey = 'nexfit.backup.key';
  static const String backupFileNamePrefix = 'nexfit_backup';

  // ---------------------------------------------------------------------
  // Security & offline sync
  // ---------------------------------------------------------------------
  /// Secure-storage prefix for versioned field-encryption keys.
  static const String encryptionKeyPrefix = 'nexfit.encryption.key.';
  /// Secure-storage key pointing to the active encryption key version.
  static const String encryptionActiveKeyStorageKey =
      'nexfit.encryption.active.key';
  /// Secure-storage key for the stable per-install device id.
  static const String deviceIdStorageKey = 'nexfit.device.id';
  static const int encryptionKeyLengthBytes = 32;
  static const int encryptionNonceLengthBytes = 12;
  static const int encryptionTagLengthBits = 128;

  /// Prefix stamped on encrypted field values so `nf1:<base64>` values are
  /// recognisable during decryption.
  static const String encryptionFieldPrefix = 'nf1:';

  /// How long completed sync events are kept before being pruned.
  static const Duration syncEventRetention = Duration(days: 14);
  /// How long error logs are kept before being pruned.
  static const Duration errorLogRetention = Duration(days: 30);
  /// How long inactive session records are kept before being pruned.
  static const Duration sessionRetention = Duration(days: 30);
  /// Maximum retry attempts before a sync event is moved to permanent failure.
  static const int syncEventMaxRetries = 3;

  // ---------------------------------------------------------------------
  // Two-way sync foundation
  // ---------------------------------------------------------------------
  /// How long a stuck PROCESSING event may age before it is reclaimed on
  /// startup (safe because a sync run never exceeds this).
  static const Duration syncStuckProcessingTimeout = Duration(minutes: 5);
  /// Exponential retry backoff (seconds) for transient push/pull failures.
  /// The last value caps the sequence. Index = attempt index - 1.
  static const List<int> syncRetryBackoffSeconds = <int>[
    2,
    5,
    15,
    30,
    60,
    120,
    300,
  ];
  /// Maximum number of pull batches drained in a single sync run.
  static const int syncMaxPullBatches = 50;
  /// Pull batch size (rows of `sync_changes` per request).
  static const int syncPullBatchSize = 100;
  /// Maximum `event_uuid` characters allowed to flow into `last_error` logs.
  static const int syncLogMaxEventUuidChars = 12;
  /// Page size for outbox queue drains.
  static const int syncQueuePageSize = 500;
  /// Monotonic id used to seed a fresh cursor for a never-synced user.
  static const int syncInitialCursor = 0;
}
