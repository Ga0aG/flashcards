class WordBook {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;

  WordBook({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WordBook.fromMap(Map<String, dynamic> map) {
    return WordBook(
      id: map['id'],
      name: map['name'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
