import 'design_layer.dart';

/// Represents a complete wrap design project.
class WrapDesign {
  final String id;
  final String vehicleModelId;
  final String vehicleName;
  final String? prompt; // AI prompt used to generate
  final String? aiProvider; // Provider used for generation
  final List<DesignLayer> layers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? thumbnailPath; // Saved thumbnail path
  final bool isFavorite;

  WrapDesign({
    required this.id,
    required this.vehicleModelId,
    required this.vehicleName,
    this.prompt,
    this.aiProvider,
    this.layers = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.thumbnailPath,
    this.isFavorite = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  WrapDesign copyWith({
    String? id,
    String? vehicleModelId,
    String? vehicleName,
    String? prompt,
    String? aiProvider,
    List<DesignLayer>? layers,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thumbnailPath,
    bool? isFavorite,
  }) {
    return WrapDesign(
      id: id ?? this.id,
      vehicleModelId: vehicleModelId ?? this.vehicleModelId,
      vehicleName: vehicleName ?? this.vehicleName,
      prompt: prompt ?? this.prompt,
      aiProvider: aiProvider ?? this.aiProvider,
      layers: layers ?? this.layers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleModelId': vehicleModelId,
      'vehicleName': vehicleName,
      'prompt': prompt,
      'aiProvider': aiProvider,
      'layers': layers.map((l) => l.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
      'isFavorite': isFavorite,
    };
  }

  factory WrapDesign.fromJson(Map<String, dynamic> json) {
    return WrapDesign(
      id: json['id'] as String,
      vehicleModelId: json['vehicleModelId'] as String,
      vehicleName: json['vehicleName'] as String,
      prompt: json['prompt'] as String?,
      aiProvider: json['aiProvider'] as String?,
      layers: (json['layers'] as List<dynamic>?)
              ?.map((l) => DesignLayer.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      thumbnailPath: json['thumbnailPath'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
