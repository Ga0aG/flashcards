class WordBook {
  final String id;
  final String language; // e.g. 'ja', 'en', 'zh', 'it', 'es'
  final int createdAt;
  final int updatedAt;

  WordBook({
    required this.id,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'language': language,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WordBook.fromMap(Map<String, dynamic> map) {
    return WordBook(
      id: map['id'],
      // fallback: old data used 'name' field
      language: map['language'] ?? map['name'] ?? 'en',
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
