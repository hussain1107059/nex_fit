import '../../core/extensions/string_extensions.dart';
import 'bangla_copy.dart';
import 'bangla_exercises_flex.dart';
import 'bangla_exercises_lower.dart';
import 'bangla_exercises_upper.dart';

export 'bangla_copy.dart';

/// Display-time Bangla overlay for seeded workout/exercise content.
///
/// The database keeps English text as the single source of truth; these maps
/// are consulted only while rendering when the active locale is Bangla.

const Map<String, BxCopy> _kBxExercises = <String, BxCopy>{
  ...kBxExercisesUpper,
  ...kBxExercisesLower,
  ...kBxExercisesFlex,
};

/// Single-word/phrase translations for body parts, muscles and equipment.
const Map<String, String> kBxWords = <String, String>{
  // Body parts
  'Chest': 'বুক',
  'Back': 'পিঠ',
  'Shoulders': 'কাঁধ',
  'Shoulder': 'কাঁধ',
  'Arms': 'হাত',
  'Arm': 'হাত',
  'Biceps': 'বাইসেপস',
  'Triceps': 'ট্রাইসেপস',
  'Legs': 'পা',
  'Leg': 'পা',
  'Calves': 'ক্যাাফ',
  'Glutes': 'নিতম্ব',
  'Core': 'কোর',
  'Abs': 'পেট',
  'Cardio': 'কার্ডিও',
  'Yoga': 'যোগ',
  'Stretching': 'স্ট্রেচিং',
  // Muscles
  'Hamstrings': 'হ্যামস্ট্রিং',
  'Quads': 'কোয়াডস',
  'Quadriceps': 'কোয়াড্রিসেপস',
  'Hip Flexors': 'হিপ ফ্লেক্সার',
  'Hips': 'হিপ',
  'Obliques': 'অবলিক',
  'Lower Abs': 'নিচের পেট',
  'Upper Abs': 'উপরের পেট',
  'Lower Back': 'নিচের পিঠ',
  'Upper Back': 'উপরের পিঠ',
  'Inner Thighs': 'ভেতরের উরু',
  'Forearms': 'ফোরআর্ম',
  'Forearm': 'ফোরআর্ম',
  'Lats': 'ল্যাটস',
  'Traps': 'ট্র্যাপস',
  'Upper Traps': 'উপরের ট্র্যাপস',
  'Anterior Deltoids': 'সামনের ডেল্টয়েড',
  'Rear Deltoids': 'পেছনের ডেল্টয়েড',
  'Rear Deltoid': 'পেছনের ডেল্টয়েড',
  'Deltoids': 'ডেল্টয়েড',
  'Rotator Cuff': 'রোটেটর কাফ',
  'Rhomboids': 'রম্বয়েডস',
  'Brachialis': 'ব্র্যাকিয়ালিস',
  'Adductors': 'অ্যাডাক্টর',
  'Abductors': 'অ্যাবডাক্টর',
  'Hip Abductors': 'হিপ অ্যাবডাক্টর',
  'Soleus': 'সোলিয়াস',
  'Ankles': 'গোড়ালি',
  'Spine': 'মেরুদণ্ড',
  'Balance': 'ভারসাম্য',
  'Long Head of Triceps': 'ট্রাইসেপসের লং হেড',
  'Inner Chest': 'বুকের ভেতরের অংশ',
  'Upper Chest': 'বুকের উপরের অংশ',
  // Equipment
  'None': 'নেই',
  'Dumbbell': 'ডাম্বেল',
  'Chair': 'চেয়ার',
  'Bench': 'বেঞ্চ',
  'Wall': 'দেয়াল',
  'Jump Rope': 'জাম্প রোপ',
  'Pull-up bar': 'পুল-আপ বার',
};

/// Category labels keyed by slug (also matches enum names / English titles).
const Map<String, String> kBxCategories = <String, String>{
  'home_workout': 'হোম ওয়ার্কআউট',
  'gym_workout': 'জিম ওয়ার্কআউট',
  'cardio': 'কার্ডিও',
  'yoga': 'যোগ',
  'strength': 'স্ট্রেংথ',
  'hiit': 'HIIT',
  'stretching': 'স্ট্রেচিং',
  'full_body': 'ফুল বডি',
  'upper_body': 'আপার বডি',
  'lower_body': 'লোয়ার বডি',
  'chest': 'বুক',
  'back': 'পিঠ',
  'shoulder': 'কাঁধ',
  'shoulders': 'কাঁধ',
  'arms': 'হাত',
  'biceps': 'বাইসেপস',
  'triceps': 'ট্রাইসেপস',
  'legs': 'পা',
  'glutes': 'নিতম্ব',
  'core': 'কোর',
  'abs': 'পেট',
  'fat_loss': 'ফ্যাট লস',
  'muscle_gain': 'মাসল গেইন',
};

/// Bangla names + descriptions for seeded workouts.
const Map<String, BxCopy> kBxWorkouts = <String, BxCopy>{
  'Morning Stretch Routine': BxCopy(
    name: 'সকালের স্ট্রেচ রুটিন',
    description:
        'এই হালকা ফুল-বডি মোবিলিটি ফ্লো দিয়ে শরীরকে জাগিয়ে তুলুন। দিনের শুরুর জন্য আদর্শ।',
  ),
  'Quick Home Warm-Up': BxCopy(
    name: 'দ্রুত হোম ওয়ার্ম-আপ',
    description:
        'হৃদস্পন্দন বাড়িয়ে শরীরকে প্রশিক্ষণের জন্য প্রস্তুত করার দ্রুত পাঁচ-মুভ ওয়ার্ম-আপ।',
  ),
  'Beginner Full Body': BxCopy(
    name: 'বিগিনার ফুল বডি',
    description:
        'সহজ, সরঞ্জামবিহীন রুটিন যা পুরো শরীরকে প্রশিক্ষণ দেয় ও শক্ত ভিত তৈরি করে।',
  ),
  'Intermediate Full Body': BxCopy(
    name: 'ইন্টারমিডিয়েট ফুল বডি',
    description:
        'প্রতিটি প্রধান পেশিগোষ্ঠী কভার করা একটি ভারসাম্যপূর্ণ স্ট্রেংথ ও কন্ডিশনিং সেশন।',
  ),
  'Advanced Full Body Blast': BxCopy(
    name: 'অ্যাডভান্সড ফুল বডি ব্লাস্ট',
    description:
        'শক্তি, পাওয়ার ও স্ট্যামিনাকে সীমায় ঠেলে দেওয়া চ্যালেঞ্জিং ফুল-বডি সার্কিট।',
  ),
  'Home HIIT': BxCopy(
    name: 'হোম HIIT',
    description:
        'মাত্র ২০ মিনিটে ক্যালোরি পোড়িয়ে মেটাবলিজম বাড়ানো হাই-ইনটেনসিটি ইন্টারভাল।',
  ),
  'Fat Burning Cardio': BxCopy(
    name: 'ফ্যাট বার্নিং কার্ডিও',
    description:
        'চর্বি গলাতে ও হৃদযন্ত্রের সুস্থতা বাড়াতে ডিজাইন করা ক্যালোরি-বার্নিং সেশন।',
  ),
  'Yoga Flow': BxCopy(
    name: 'যোগ ফ্লো',
    description: 'নমনীয়তা, ভারসাম্য ও মনোযোগ বাড়ানো প্রশান্ত যোগ সিকোয়েন্স।',
  ),
  'Stretch & Recover': BxCopy(
    name: 'স্ট্রেচ অ্যান্ড রিকভার',
    description:
        'টান ছাড়িয়ে পেশির দ্রুত রিকভারি দেওয়া রিকভারি-কেন্দ্রিক স্ট্রেচিং রুটিন।',
  ),
  'Core Crusher': BxCopy(
    name: 'কোর ক্রাশার',
    description:
        'শক্তিশালী ও সুগঠিত কোর তৈরিতে মনোযোগী ১৫ মিনিটের পেটের ব্যায়াম।',
  ),
  'Advanced Core': BxCopy(
    name: 'অ্যাডভান্সড কোর',
    description:
        'যারা সিরিয়াস পেটের পেশি চান তাদের জন্য চ্যালেঞ্জিং কোর সার্কিট।',
  ),
  'Upper Body Strength': BxCopy(
    name: 'আপার বডি স্ট্রেংথ',
    description:
        'বুক, পিঠ, কাঁধ ও হাতকে টার্গেট করা সম্পূর্ণ আপার-বডি সেশন।',
  ),
  'Beginner Upper Body': BxCopy(
    name: 'বিগিনার আপার বডি',
    description:
        'বিগিনার-বান্ধব মুভ দিয়ে শক্তি তৈরির সহজ আপার-বডি রুটিন।',
  ),
  'Chest Builder': BxCopy(
    name: 'চেস্ট বিল্ডার',
    description:
        'বাড়িতে বড় ও শক্তিশালী বুক তৈরির জন্য ডিজাইন করা পুশ-আপ ও প্রেস।',
  ),
  'Back Builder': BxCopy(
    name: 'ব্যাক বিল্ডার',
    description:
        'পিঠের প্রস্থ, পুরুত্ব ও ভঙ্গিমা তৈরির পুলিং-কেন্দ্রিক সেশন।',
  ),
  'Shoulder Sculpt': BxCopy(
    name: 'শোল্ডার স্কাল্পট',
    description: 'শক্ত গোলাকার কাঁধ গড়তে প্রেস ও রেইজ।',
  ),
  'Arm Blaster': BxCopy(
    name: 'আর্ম ব্লাস্টার',
    description: 'সুগঠিত হাত তৈরির জন্য বাইসেপস, ট্রাইসেপস ও ফোরআর্মের কাজ।',
  ),
  'Leg Day': BxCopy(
    name: 'লেগ ডে',
    description: 'শক্তিশালী পা তৈরির সম্পূর্ণ লোয়ার-বডি সেশন।',
  ),
  'Beginner Legs': BxCopy(
    name: 'বিগিনার লেগস',
    description: 'মৌলিক মুভমেন্ট দিয়ে লোয়ার-বডি প্রশিক্ষণের সহজ শুরু।',
  ),
  'Advanced Legs': BxCopy(
    name: 'অ্যাডভান্সড লেগস',
    description:
        'সিরিয়াস পায়ের শক্তি চাওয়া অভিজ্ঞদের জন্য কঠোর লোয়ার-বডি সার্কিট।',
  ),
  'Lower Body Focus': BxCopy(
    name: 'লোয়ার বডি ফোকাস',
    description:
        'পা, নিতম্ব ও কোরে মনোনিবেশ করা বিগিনার-বান্ধব সেশন।',
  ),
  'Home No-Equipment': BxCopy(
    name: 'হোম নো-একুইপমেন্ট',
    description:
        'যেকোনো জায়গায় শূন্য সরঞ্জামে করা যায় এমন সম্পূর্ণ বডিওয়েট ওয়ার্কআউট।',
  ),
  'Gym Strength': BxCopy(
    name: 'জিম স্ট্রেংথ',
    description: 'জিম ফ্লোরের জন্য তৈরি ডাম্বেল-ভিত্তিক স্ট্রেংথ সেশন।',
  ),
  'Fat Loss Booster': BxCopy(
    name: 'ফ্যাট লস বুস্টার',
    description:
        'ফ্যাট কমানো দ্রুত করতে স্ট্রেংথ ও কার্ডিওর সমন্বয়ে মেটাবলিক সেশন।',
  ),
  'Muscle Builder': BxCopy(
    name: 'মাসল বিল্ডার',
    description:
        'লিন মাসল তৈরির জন্য ডিজাইন করা হাইপারট্রফি-কেন্দ্রিক সেশন।',
  ),
  'Beginner HIIT': BxCopy(
    name: 'বিগিনার HIIT',
    description:
        'দীর্ঘ বিশ্রাম ও সহজ মুভ সহ ইন্টারভাল ট্রেনিংয়ের মৃদু শুরু।',
  ),
};

/// True when seeded content should render in Bangla.
bool bxActive() {
  final String code = DigitLocale.currentLanguageCode.toLowerCase();
  return code == 'bs' || code == 'bn';
}

/// Bangla overlay copy for an exercise, or null when inactive/not found.
BxCopy? bxExerciseCopy(String englishName) =>
    bxActive() ? _kBxExercises[englishName] : null;

/// Bangla overlay copy for a workout, or null when inactive/not found.
BxCopy? bxWorkoutCopy(String englishName) =>
    bxActive() ? kBxWorkouts[englishName] : null;

/// Exercise display name in the active locale.
String bxExerciseName(String englishName) {
  if (!bxActive()) return englishName;
  return _kBxExercises[englishName]?.name ?? englishName;
}

/// Workout display name in the active locale.
String bxWorkoutName(String englishName) {
  if (!bxActive()) return englishName;
  return kBxWorkouts[englishName]?.name ?? englishName;
}

/// Translates a comma-separated auxiliary string (body part, secondary
/// muscle or equipment). Falls back to per-token lookup, then to the input.
String bxAux(String value) {
  if (!bxActive() || value.trim().isEmpty) return value;
  final String? exact = kBxWords[value.trim()];
  if (exact != null) return exact;
  final List<String> parts = value.split(',');
  final bool translatable = parts.every(
    (String part) => kBxWords.containsKey(part.trim()),
  );
  if (!translatable) return value;
  return parts.map((String part) => kBxWords[part.trim()]!).join(', ');
}

/// Category label translation; accepts slug, enum name or English title.
String bxCategoryLabel(String raw) {
  if (!bxActive() || raw.isEmpty) return raw;
  final String key = raw.trim().toLowerCase().replaceAll(' ', '_');
  return kBxCategories[key] ?? raw;
}

/// Picks an overlay string list, falling back to the English source.
List<String> bxList(
  BxCopy? copy,
  List<String>? Function(BxCopy) pick,
  List<String> fallback,
) {
  if (copy == null) return fallback;
  final List<String>? list = pick(copy);
  if (list == null || list.isEmpty) return fallback;
  return list;
}
