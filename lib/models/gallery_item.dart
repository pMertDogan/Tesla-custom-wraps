/// Represents a saved gallery item for the community gallery.
class GalleryItem {
  final String id;
  final String vehicleModelId;
  final String vehicleName;
  final String designName;
  final String authorName;
  final String? thumbnailPath;
  final String? designPath; // Full design image
  final String? prompt; // AI prompt used
  final int likes;
  final bool isLiked;
  final DateTime createdAt;

  GalleryItem({
    required this.id,
    required this.vehicleModelId,
    required this.vehicleName,
    required this.designName,
    required this.authorName,
    this.thumbnailPath,
    this.designPath,
    this.prompt,
    this.likes = 0,
    this.isLiked = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  GalleryItem copyWith({
    String? id,
    String? vehicleModelId,
    String? vehicleName,
    String? designName,
    String? authorName,
    String? thumbnailPath,
    String? designPath,
    String? prompt,
    int? likes,
    bool? isLiked,
    DateTime? createdAt,
  }) {
    return GalleryItem(
      id: id ?? this.id,
      vehicleModelId: vehicleModelId ?? this.vehicleModelId,
      vehicleName: vehicleName ?? this.vehicleName,
      designName: designName ?? this.designName,
      authorName: authorName ?? this.authorName,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      designPath: designPath ?? this.designPath,
      prompt: prompt ?? this.prompt,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleModelId': vehicleModelId,
      'vehicleName': vehicleName,
      'designName': designName,
      'authorName': authorName,
      'thumbnailPath': thumbnailPath,
      'designPath': designPath,
      'prompt': prompt,
      'likes': likes,
      'isLiked': isLiked,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GalleryItem.fromJson(Map<String, dynamic> json) {
    return GalleryItem(
      id: json['id'] as String,
      vehicleModelId: json['vehicleModelId'] as String,
      vehicleName: json['vehicleName'] as String,
      designName: json['designName'] as String,
      authorName: json['authorName'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      designPath: json['designPath'] as String?,
      prompt: json['prompt'] as String?,
      likes: json['likes'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
