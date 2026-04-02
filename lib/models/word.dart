class Word {
  final String id;
  final String wordBookId;
  final String front;
  final String back;
  final String notes;
  final List<String> tags;
  final String pronunciation;
  final int memoryLevel;
  final int lastCorrectAt;
  final int createdAt;
  final bool swipedRightInSession;

  Word({
    required this.id,
    required this.wordBookId,
    required this.front,
    required this.back,
    required this.notes,
    required this.tags,
    required this.pronunciation,
    required this.memoryLevel,
    required this.lastCorrectAt,
    required this.createdAt,
    this.swipedRightInSession = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wordbook_id': wordBookId,
      'front': front,
      'back': back,
      'notes': notes,
      'tags': tags.join(','),
      'pronunciation': pronunciation,
      'memory_level': memoryLevel,
      'last_correct_at': lastCorrectAt,
      'created_at': createdAt,
    };
  }

  Word copyWith({
    String? id,
    String? wordBookId,
    String? front,
    String? back,
    String? notes,
    List<String>? tags,
    String? pronunciation,
    int? memoryLevel,
    int? lastCorrectAt,
    int? createdAt,
    bool? swipedRightInSession,
  }) {
    return Word(
      id: id ?? this.id,
      wordBookId: wordBookId ?? this.wordBookId,
      front: front ?? this.front,
      back: back ?? this.back,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      pronunciation: pronunciation ?? this.pronunciation,
      memoryLevel: memoryLevel ?? this.memoryLevel,
      lastCorrectAt: lastCorrectAt ?? this.lastCorrectAt,
      createdAt: createdAt ?? this.createdAt,
      swipedRightInSession: swipedRightInSession ?? this.swipedRightInSession,
    );
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      wordBookId: map['wordbook_id'],
      front: map['front'],
      back: map['back'],
      notes: map['notes'] ?? '',
      tags: (map['tags'] as String).split(',').where((t) => t.isNotEmpty).toList(),
      pronunciation: map['pronunciation'] ?? '',
      memoryLevel: map['memory_level'],
      lastCorrectAt: map['last_correct_at'],
      createdAt: map['created_at'],
    );
  }
}
