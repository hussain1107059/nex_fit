/// A daily motivational quote available in Bangla and English.
class MotivationalQuote {
  const MotivationalQuote({required this.bangla, required this.english});

  final String bangla;
  final String english;
}

/// Rotating pool of motivational quotes for the dashboard.
class MotivationalQuotes {
  MotivationalQuotes._();

  static const List<MotivationalQuote> all = <MotivationalQuote>[
    MotivationalQuote(
      bangla: 'কোনো লক্ষ্য অতিরিক্ত বড় নয়; শুধু ছোট ছোট পদক্ষেপে ভাগ করুন।',
      english: 'No goal is too big; just break it into smaller steps.',
    ),
    MotivationalQuote(
      bangla: 'শরীর যা পারে, মন তার অর্ধেকও বিশ্বাস করে না।',
      english: 'The body achieves what the mind believes.',
    ),
    MotivationalQuote(
      bangla: 'পরিশ্রমের কোনো বিকল্প নেই — আজকের ঘামই আগামীর শক্তি।',
      english: 'There is no substitute for hard work — today\'s sweat is tomorrow\'s strength.',
    ),
    MotivationalQuote(
      bangla: 'সফল হতে হলে প্রথমে হাজির হতে হয়।',
      english: 'Success starts with simply showing up.',
    ),
    MotivationalQuote(
      bangla: 'আপনি যা পুনরাবৃত্তি করেন, তাই আপনি হয়ে ওঠেন।',
      english: 'You become what you repeat.',
    ),
    MotivationalQuote(
      bangla: 'এক গ্লাস পানি আজ, এক ধাপ কাছাকাছি আগামীকাল।',
      english: 'One glass of water today, one step closer tomorrow.',
    ),
    MotivationalQuote(
      bangla: 'দুর্বল না, শক্তিশালী হওয়ার সিদ্ধান্তই যথেষ্ট।',
      english: 'Deciding to be strong is half the battle.',
    ),
    MotivationalQuote(
      bangla: 'প্রতিদিন একটু ভালো, গতকালের চেয়ে।',
      english: 'Every day, be a little better than yesterday.',
    ),
    MotivationalQuote(
      bangla: 'স্থিরতা সাফল্যের চাবিকাঠি — থেমে যাবেন না।',
      english: 'Consistency is the key — don\'t stop.',
    ),
    MotivationalQuote(
      bangla: 'আপনার শরীর আপনাকে ধন্যবাদ জানাবে প্রতিদিনের যত্নে।',
      english: 'Your body will thank you for the daily care.',
    ),
    MotivationalQuote(
      bangla: 'ছোট ছোট জয়গুলোই বড় স্বপ্ন পূরণ করে।',
      english: 'Small wins add up to big dreams.',
    ),
    MotivationalQuote(
      bangla: 'আজ যা করেননি, আগামীকালও করতে চাইবেন না।',
      english: 'What you put off today, you will avoid tomorrow too.',
    ),
  ];
}
