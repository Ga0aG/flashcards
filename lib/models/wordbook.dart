class WordBook {
  final String id;
  final String language;
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

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'language': language,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted': false,
    };
  }

  factory WordBook.fromMap(Map<String, dynamic> map) {
    return WordBook(
      id: map['id'],
      language: map['language'] ?? map['name'] ?? 'en',
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  factory WordBook.fromFirestoreMap(Map<String, dynamic> map) {
    return WordBook(
      id: map['id'],
      language: map['language'] ?? 'en',
      createdAt: map['created_at'] ?? 0,
      updatedAt: map['updated_at'] ?? 0,
    );
  }
}
