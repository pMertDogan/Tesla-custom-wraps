import 'dart:typed_data';

/// A wrap design produced by the AI, kept in memory for the session.
class WrapDesign {
  /// Unique id of the design.
  final String id;

  /// Id of the [TeslaModel] the design was generated for.
  final String modelId;

  /// The user prompt that produced this design.
  final String prompt;

  /// Encoded image bytes (PNG or JPEG depending on the provider).
  final Uint8List bytes;

  /// MIME type of [bytes].
  final String mimeType;

  /// Id of the provider that generated the design.
  final String providerId;

  /// When the design was generated.
  final DateTime createdAt;

  const WrapDesign({
    required this.id,
    required this.modelId,
    required this.prompt,
    required this.bytes,
    required this.mimeType,
    required this.providerId,
    required this.createdAt,
  });

  @override
  String toString() => 'WrapDesign($id, model: $modelId)';
}
