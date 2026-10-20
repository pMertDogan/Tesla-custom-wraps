/// A Tesla vehicle that can receive a custom wrap.
///
/// Asset paths follow the layout published in `teslamotors/custom-wraps`:
/// every vehicle owns a folder containing the paintable UV template
/// (`template.png`), a reference render (`vehicle_image.png`) and Tesla's own
/// example designs (`example/*.png`).
class TeslaModel {
  /// Stable key used in routes, storage and generated-design bookkeeping.
  final String id;

  /// Human readable name shown in the UI.
  final String name;

  /// One line marketing description shown on the model card.
  final String description;

  /// Asset folder name, relative to the package root.
  ///
  /// This is also the folder published by Tesla, e.g. `model3-2024-base`.
  final String folder;

  /// Optional GLB vehicle model, used by the 3D preview milestone.
  ///
  /// Kept nullable so a vehicle can be listed before its 3D asset exists.
  final String? glbPath;

  /// File names of Tesla's example wraps inside `<folder>/example/`.
  final List<String> exampleNames;

  /// Pixel width of [templatePath] as published by Tesla.
  final int templateWidth;

  /// Pixel height of [templatePath] as published by Tesla.
  final int templateHeight;

  const TeslaModel({
    required this.id,
    required this.name,
    required this.description,
    required this.folder,
    required this.exampleNames,
    required this.templateWidth,
    required this.templateHeight,
    this.glbPath,
  });

  /// Reference render of the vehicle.
  String get imagePath => '$folder/vehicle_image.png';

  /// Paintable UV atlas. White areas of this image are what gets designed on.
  String get templatePath => '$folder/template.png';

  /// Full asset paths of Tesla's example wraps for this vehicle.
  List<String> get exampleWraps =>
      exampleNames.map((name) => '$folder/example/$name').toList();

  /// Number of example designs Tesla ships for this vehicle.
  int get exampleCount => exampleNames.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TeslaModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TeslaModel($id)';
}
