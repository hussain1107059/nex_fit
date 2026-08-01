# Flutter's generated R8 rules (flutter_rules.pro) already cover the engine
# and the plugin registrant. Add project-specific keep rules below if a plugin
# class is stripped at runtime.

# google_sign_in / Google APIs reflection
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.client.** { *; }

# flutter_local_notifications (JSON/reflection based scheduling)
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# local_auth biometrics
-keep class io.flutter.plugins.localauth.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
