class Settings {
  final String mainLanguage;
  final int defaultReviewCount;

  Settings({
    required this.mainLanguage,
    this.defaultReviewCount = 20,
  });

  Map<String, dynamic> toMap() {
    return {
      'main_language': mainLanguage,
      'default_review_count': defaultReviewCount,
    };
  }

  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      mainLanguage: map['main_language'],
      defaultReviewCount: map['default_review_count'],
    );
  }
}
