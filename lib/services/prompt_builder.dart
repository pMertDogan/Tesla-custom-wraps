/// Builds the prompts that turn a short user idea into a vehicle wrap texture.
///
/// The hard part of AI wrap generation is not "make a pretty picture", it is
/// "make a flat 2D texture atlas that maps onto a real car". These builders
/// spell out that contract explicitly, and optionally hand the model Tesla's
/// own UV template as a reference image so the panel layout is preserved.
class WrapPromptBuilder {
  const WrapPromptBuilder._();

  /// Maximum length of the user supplied concept.
  static const int maxConceptLength = 1000;

  /// Builds the generation prompt.
  ///
  /// [concept] is the user's raw description.
  /// [vehicleName] is used to make the prompt concrete.
  /// [style] is an optional style hint (see [WrapStyle.presets]).
  /// [hasReferenceTemplate] is true when the model's UV template is attached
  /// to the request as a reference image.
  /// [flatPatternOnly] switches to the short pattern prompt used by
  /// providers that ignore the reference image and only read the prompt.
  static String build({
    required String concept,
    required String vehicleName,
    String? style,
    bool hasReferenceTemplate = true,
    bool flatPatternOnly = false,
  }) {
    if (flatPatternOnly) {
      return buildPattern(concept: concept, style: style);
    }

    final cleaned = sanitizeConcept(concept);
    final styleHint = (style == null || style.trim().isEmpty)
        ? WrapStyle.defaultStyleHint
        : style.trim();

    final buffer = StringBuffer()
      ..writeln(
        'You are a vehicle wrap texture artist working on the official Tesla '
        'Paint Shop template for the $vehicleName.',
      )
      ..writeln()
      ..writeln('CONCEPT')
      ..writeln(cleaned.isEmpty ? '(no description given, invent a striking '
          'wrap)' : cleaned)
      ..writeln()
      ..writeln('OUTPUT CONTRACT')
      ..writeln(
        '- Deliver ONE flat 2D texture sheet: a straight-on, orthographic UV '
        'unwrap of the whole vehicle.',
      );

    if (hasReferenceTemplate) {
      buffer
        ..writeln(
          '- The attached reference image is the exact UV atlas for this '
          'vehicle. Reproduce its panel outlines, panel positions and '
          'proportions precisely.',
        )
        ..writeln(
          '- Only the white (paintable) areas receive artwork. Keep every '
          'panel border as a clean cut line.',
        );
    } else {
      buffer.writeln(
        '- Lay the pattern out as a square texture atlas: hood and roof in '
        'the upper half, side panels across the middle, bumpers and lower '
        'panels along the bottom.',
      );
    }

    buffer
      ..writeln(
        '- The artwork must bleed to the edge of every panel and read as one '
        'continuous surface once the panels are wrapped around the car.',
      )
      ..writeln(
        '- Never draw the car itself, and never draw wheels, windows, '
        'mirrors, shadow, reflection, floor, studio backdrop or perspective. '
        'The result must be a pure texture, not a render.',
      )
      ..writeln(
        '- No text, letters, numbers, brand logos, watermarks or badges.',
      )
      ..writeln(
        '- Flat, evenly lit colour. No vignette, no lens effect, no drop '
        'shadow, no depth of field.',
      )
      ..writeln(
        '- High contrast and clean edges so the pattern stays legible on a '
        'real vehicle under daylight.',
      )
      ..writeln()
      ..writeln('STYLE')
      ..writeln(styleHint)
      ..writeln()
      ..writeln(
        'Return a full-bleed square texture sheet and nothing else.',
      );

    return buffer.toString();
  }

  /// Builds the short prompt used by providers that ignore the reference
  /// image and only read the prompt.
  ///
  /// These providers are told to draw a flat pattern rather than a vehicle,
  /// and the studio's panel mask clips that pattern onto the real body
  /// panels afterwards. The wording is deliberately compact: some of these
  /// services carry the prompt in the URL, where every character counts.
  ///
  /// The wording is positive on purpose. Naming a vehicle, even to rule it
  /// out, is enough to make an image model render one, and a wrap that shows
  /// a photo of a car instead of a pattern is worthless. The prompt therefore
  /// describes what the frame should hold and stays silent about cars.
  static String buildPattern({
    required String concept,
    String? style,
  }) {
    final cleaned = sanitizePatternConcept(sanitizeConcept(concept));
    final styleHint = (style == null || style.trim().isEmpty)
        ? WrapStyle.defaultStyleHint
        : style.trim();

    final buffer = StringBuffer()
      ..writeln('Full bleed seamless abstract texture pattern, edge to edge.')
      ..writeln()
      ..writeln('CONCEPT')
      ..writeln(cleaned.isEmpty ? 'invent a striking texture pattern' : cleaned)
      ..writeln()
      ..writeln('STYLE')
      ..writeln(styleHint)
      ..writeln()
      ..writeln(
        'One flat printed surface, pure pattern, nothing else in the frame.',
      )
      ..writeln(
        'Seamless and tileable, evenly lit, high contrast, clean edges, poster '
        'quality.',
      );

    return buffer.toString();
  }

  /// Words that send the model straight back to drawing the car.
  ///
  /// A provider that only reads the prompt gets a template as a colour cue
  /// but no layout, so mentioning the vehicle in the concept makes it render
  /// a photo of that vehicle instead of the wrap pattern. The vehicle is
  /// irrelevant for a flat pattern, the panel mask places it on the car.
  static const List<String> _vehicleWords = [
    'cybertruck',
    'cyber truck',
    'model 3',
    'model3',
    'model s',
    'model x',
    'model y',
    'model l',
    'models',
    'modely',
    'modelx',
    'modell',
    'tesla',
    'car',
    'vehicle',
    'automobile',
    'jeep',
    'van',
    'truck',
    'sedan',
    'suv',
    'coupe',
    'hatchback',
  ];

  /// Strips the vehicle out of a concept for providers that draw a flat
  /// pattern.
  ///
  /// The words are removed as whole words, so a design called "Model of
  /// behaviour" keeps its meaning while "a red cybertruck wrap" becomes "a
  /// red wrap".
  static String sanitizePatternConcept(String concept) {
    var result = concept;
    for (final word in _vehicleWords) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false),
        ' ',
      );
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalises the raw user input: trims, collapses whitespace and clips
  /// to [maxConceptLength].
  static String sanitizeConcept(String concept) {
    final collapsed = concept.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= maxConceptLength) return collapsed;
    return collapsed.substring(0, maxConceptLength).trim();
  }
}

/// Ready-made style directions a user can pick instead of writing one.
class WrapStyle {
  const WrapStyle(this.id, this.label, this.hint);

  /// Stable key.
  final String id;

  /// Label shown in the style picker.
  final String label;

  /// Style instruction appended to the prompt.
  final String hint;

  /// Style used when the user has not picked one.
  static const String defaultStyleHint =
      'Crisp vector-like graphics with clean edges and poster quality.';

  /// The built-in styles.
  static const List<WrapStyle> presets = [
    WrapStyle(
      'vector',
      'Graphic vector',
      'Crisp vector-like graphics with clean edges and poster quality.',
    ),
    WrapStyle(
      'camo',
      'Digital camo',
      'Modern digital camouflage built from hard-edged angular blocks in a '
          'tightly controlled palette.',
    ),
    WrapStyle(
      'gradient',
      'Gradient mesh',
      'Smooth flowing multi-stop gradient mesh, silky and luminous, with no '
          'visible banding.',
    ),
    WrapStyle(
      'retro',
      'Retro stripes',
      'Bold racing stripes and period racing livery with strong 70s motorsport '
          'energy.',
    ),
    WrapStyle(
      'pixel',
      'Pixel art',
      'Detailed 16-bit pixel art scene with a strict limited palette and '
          'visible pixel grid.',
    ),
    WrapStyle(
      'nature',
      'Organic nature',
      'Organic natural forms, topographic contour lines and botanical shapes '
          'in muted earth tones.',
    ),
    WrapStyle(
      'space',
      'Deep space',
      'Cosmic nebula field with stars and glowing plasma, high contrast '
          'blacks and saturated highlights.',
    ),
    WrapStyle(
      'concrete',
      'Raw industrial',
      'Weathered concrete and brushed metal surface with subtle grime and '
          'stencil marks.',
    ),
  ];

  /// Looks a style up by id, falling back to the vector preset.
  static WrapStyle byId(String id) {
    for (final style in presets) {
      if (style.id == id) return style;
    }
    return presets.first;
  }
}
