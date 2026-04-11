class TeslaModel {
  final String id;
  final String name;
  final String description;
  final String imagePath;
  final String templatePath;
  final String glbPath;
  final List<String> exampleWraps;

  TeslaModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.templatePath,
    required this.glbPath,
    required this.exampleWraps,
  });
}
