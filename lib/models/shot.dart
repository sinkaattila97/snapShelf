class Shot {
  const Shot({
    required this.id,
    required this.label,
    required this.shelves,
    required this.createdAt,
    this.localPath,
    this.photoAssetId,
  });

  final String id;
  final String label;
  final List<String> shelves;
  final DateTime createdAt;

  /// App-local copy for thumbnails / offline browse.
  final String? localPath;

  /// Photos / MediaStore asset id — required to delete from the device library.
  final String? photoAssetId;

  bool get linkedToPhotos => photoAssetId != null && photoAssetId!.isNotEmpty;

  bool get needsLabel => label.trim().isEmpty;

  String get displayLabel => needsLabel ? 'Unlabeled' : label.trim();

  Shot copyWith({
    String? id,
    String? label,
    List<String>? shelves,
    DateTime? createdAt,
    String? localPath,
    String? photoAssetId,
  }) {
    return Shot(
      id: id ?? this.id,
      label: label ?? this.label,
      shelves: shelves ?? this.shelves,
      createdAt: createdAt ?? this.createdAt,
      localPath: localPath ?? this.localPath,
      photoAssetId: photoAssetId ?? this.photoAssetId,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'label': label,
      'shelves': shelves.join(','),
      'createdAt': createdAt.toIso8601String(),
      'localPath': localPath,
      'photoAssetId': photoAssetId,
    };
  }

  factory Shot.fromMap(Map<String, Object?> map) {
    final shelvesRaw = (map['shelves'] as String?) ?? '';
    final shelves = shelvesRaw.isEmpty
        ? <String>[]
        : shelvesRaw.split(',').where((s) => s.isNotEmpty).toList();
    // Migrate old "Inbox" tag → Unlabeled.
    final migrated = shelves
        .map((s) => s == 'Inbox' ? ShelfCatalog.unlabeled : s)
        .toSet()
        .toList();
    return Shot(
      id: map['id'] as String,
      label: map['label'] as String,
      shelves: migrated.isEmpty ? [ShelfCatalog.unlabeled] : migrated,
      createdAt: DateTime.parse(map['createdAt'] as String),
      localPath: map['localPath'] as String?,
      photoAssetId: map['photoAssetId'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'shelves': shelves,
        'createdAt': createdAt.toIso8601String(),
        'localPath': localPath,
        'photoAssetId': photoAssetId,
      };

  factory Shot.fromJson(Map<String, Object?> json) {
    final shelvesJson = json['shelves'];
    final shelves = shelvesJson is List
        ? shelvesJson.map((e) => e.toString()).toList()
        : <String>[];
    final migrated = shelves
        .map((s) => s == 'Inbox' ? ShelfCatalog.unlabeled : s)
        .toSet()
        .toList();
    return Shot(
      id: json['id'] as String,
      label: json['label'] as String,
      shelves: migrated.isEmpty ? [ShelfCatalog.unlabeled] : migrated,
      createdAt: DateTime.parse(json['createdAt'] as String),
      localPath: json['localPath'] as String?,
      photoAssetId: json['photoAssetId'] as String?,
    );
  }
}

/// Built-in + default shelf names.
class ShelfCatalog {
  static const unlabeled = 'Unlabeled';

  static const builtins = <String>[
    unlabeled,
    'Bug',
    'Work',
    'Receipt',
    'Meme',
    'Keep',
  ];

  /// @Deprecated — use [unlabeled]
  static const inbox = unlabeled;
}
