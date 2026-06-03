class ScenarioSentence {
  String side; // 'left' | 'right'
  String sourceText; // 中文原文
  Map<String, String> translations; // { 'ja': '...', 'en': '...' }

  ScenarioSentence({
    required this.side,
    required this.sourceText,
    Map<String, String>? translations,
  }) : translations = translations ?? {};

  Map<String, dynamic> toMap() => {
        'side': side,
        'source_text': sourceText,
        'translations': translations,
      };

  factory ScenarioSentence.fromMap(Map<String, dynamic> map) {
    final raw = map['translations'];
    final tr = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is String) tr[k.toString()] = v;
      });
    }
    return ScenarioSentence(
      side: (map['side'] as String?) ?? 'left',
      sourceText: (map['source_text'] as String?) ?? '',
      translations: tr,
    );
  }
}

class Scenario {
  final String id;
  String name;
  final int createdAt;
  int updatedAt;
  List<ScenarioSentence> sentences;

  Scenario({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    List<ScenarioSentence>? sentences,
  }) : sentences = sentences ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'sentences': sentences.map((s) => s.toMap()).toList(),
      };

  Map<String, dynamic> toFirestoreMap() => {
        ...toMap(),
        'deleted': false,
      };

  factory Scenario.fromMap(Map<String, dynamic> map) {
    final list = (map['sentences'] as List?) ?? const [];
    return Scenario(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      createdAt: (map['created_at'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as int?) ?? 0,
      sentences: list
          .map((e) => ScenarioSentence.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
