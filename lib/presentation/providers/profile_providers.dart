import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/health_calculator.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/profile_data.dart';
import '../../domain/entities/user_profile.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

/// Loads and refreshes the complete profile aggregate for the signed-in user.
class ProfileController extends AsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() {
    return _load();
  }

  Future<ProfileData> _load() async {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Profile requires a signed-in user');
    }
    return ref.read(profileRepositoryProvider).load(user.id);
  }

  /// Re-runs the aggregation so the screen reflects saved changes.
  Future<void> refresh() async {
    state = AsyncValue<ProfileData>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  /// Persists every editable profile field and recomputes the daily
  /// calorie/water targets from the new body data.
  Future<void> updateProfile({
    required String name,
    DateTime? birthDate,
    Gender? gender,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    GoalType? fitnessGoal,
    ActivityLevel? activityLevel,
    String? country,
    String? language,
    String? timezone,
    String? photoPath,
  }) async {
    final ProfileData? data = state.valueOrNull;
    if (data == null) return;
    final AppUser user = data.user;
    final UserProfile? existing = data.profile;

    final int? age = HealthCalculator.age(birthDate);
    final double? bmr = HealthCalculator.bmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final double? dailyCalories = HealthCalculator.dailyCalories(
      bmrValue: bmr,
      level: activityLevel,
    );

    final UserProfile updated = UserProfile(
      userId: user.id,
      heightCm: heightCm,
      weightKg: weightKg,
      targetWeightKg: targetWeightKg,
      gender: gender,
      birthDate: birthDate,
      activityLevel: activityLevel,
      fitnessGoal: fitnessGoal,
      country: country,
      language: language,
      timezone: timezone ?? existing?.timezone,
      photoPath: photoPath ?? existing?.photoPath,
      targetCalories: dailyCalories ?? existing?.targetCalories,
      targetProtein: existing?.targetProtein,
      targetCarbs: existing?.targetCarbs,
      targetFat: existing?.targetFat,
      targetWaterMl: HealthCalculator.waterTargetMl(weightKg),
      targetSteps: existing?.targetSteps ?? HealthCalculator.defaultStepTarget,
      updatedAt: DateTime.now(),
    );

    await ref.read(profileRepositoryProvider).saveProfile(updated);

    final String nameTrimmed = name.trim();
    if (nameTrimmed.isNotEmpty &&
        nameTrimmed != (user.displayName ?? '')) {
      await ref
          .read(profileRepositoryProvider)
          .updateName(user.id, nameTrimmed);
    }
    await refresh();
  }

  /// Picks, compresses and stores a new profile photo, updating instantly.
  Future<String?> updatePhoto({required ImageSource source}) async {
    final ProfileData? data = state.valueOrNull;
    if (data == null) return null;
    final String userId = data.user.id;

    final String? newPath = await ref
        .read(profilePhotoServiceProvider)
        .saveForUser(userId: userId, source: source);
    if (newPath == null) return null;

    final UserProfile? existing = data.profile;
    final String? oldPath = existing?.photoPath;
    if (oldPath != null && oldPath.isNotEmpty && oldPath != newPath) {
      await ref.read(profilePhotoServiceProvider).deletePhoto(oldPath);
    }

    await ref.read(profileRepositoryProvider).saveProfile(
      _withPhotoPath(existing, newPath, userId),
    );
    await refresh();
    return newPath;
  }

  /// Removes the current profile photo.
  Future<void> removePhoto() async {
    final ProfileData? data = state.valueOrNull;
    final UserProfile? existing = data?.profile;
    if (data == null || existing == null) return;

    final String? oldPath = existing.photoPath;
    if (oldPath != null && oldPath.isNotEmpty) {
      await ref.read(profilePhotoServiceProvider).deletePhoto(oldPath);
    }
    await ref
        .read(profileRepositoryProvider)
        .saveProfile(_withPhotoPath(existing, null, data.user.id));
    await refresh();
  }

  UserProfile _withPhotoPath(
    UserProfile? existing,
    String? photoPath,
    String userId,
  ) {
    return UserProfile(
      userId: userId,
      heightCm: existing?.heightCm,
      weightKg: existing?.weightKg,
      targetWeightKg: existing?.targetWeightKg,
      gender: existing?.gender,
      birthDate: existing?.birthDate,
      activityLevel: existing?.activityLevel,
      fitnessGoal: existing?.fitnessGoal,
      country: existing?.country,
      language: existing?.language,
      timezone: existing?.timezone,
      photoPath: photoPath,
      targetCalories: existing?.targetCalories,
      targetProtein: existing?.targetProtein,
      targetCarbs: existing?.targetCarbs,
      targetFat: existing?.targetFat,
      targetWaterMl: existing?.targetWaterMl,
      targetSteps: existing?.targetSteps,
      updatedAt: DateTime.now(),
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileData>(
      ProfileController.new,
    );

/// Loads the signed-in user's application settings (notification switch).
class ProfileSettingsController extends AsyncNotifier<AppSettings?> {
  @override
  Future<AppSettings?> build() {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) return Future<AppSettings?>.value();
    return ref.read(appSettingsRepositoryProvider).getByUserId(user.id);
  }

  Future<void> toggleNotifications(bool enabled) async {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) return;

    final AppSettings? current = state.valueOrNull;
    final AppSettings updated = (current ?? AppSettings(
      userId: user.id,
      updatedAt: DateTime.now(),
    )).copyWith(
      notificationsEnabled: enabled,
      updatedAt: DateTime.now(),
    );
    await ref.read(appSettingsRepositoryProvider).upsert(updated);
    state = AsyncData<AppSettings?>(updated);
  }
}

final profileSettingsProvider =
    AsyncNotifierProvider<ProfileSettingsController, AppSettings?>(
      ProfileSettingsController.new,
    );
