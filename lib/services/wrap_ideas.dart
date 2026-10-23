import 'dart:math';

import 'prompt_builder.dart';

/// A ready made design idea the studio can offer when the user has no prompt.
class WrapIdea {
  /// The short concept that goes into the prompt.
  final String concept;

  /// Style preset the concept was built for.
  final WrapStyle style;

  /// Creates an idea.
  const WrapIdea({required this.concept, required this.style});

  @override
  String toString() => 'WrapIdea(${style.id}: $concept)';
}

/// Invents wrap concepts so the studio can draw a design without a prompt.
///
/// Every idea is assembled from the pools below, which keeps the results
/// varied but always describable to an image model: a colour story, a pattern,
/// a material and, sometimes, a mood. The wording never mentions a car or a
/// vehicle, because naming one makes a text-to-image model render a car
/// instead of a wrap pattern.
///
/// The generator is seeded, so the command line tool and the tests get
/// reproducible ideas while the studio passes the clock.
class WrapIdeaGenerator {
  /// Creates a generator. [random] defaults to an unseeded [Random].
  WrapIdeaGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Colour stories. Each one is a full palette, not a single hue, because a
  /// wrap with one flat colour is not a design.
  static const List<String> palettes = [
    'midnight navy with electric cyan accents',
    'burnt orange fading into deep charcoal',
    'forest green with cream and brass highlights',
    'hot magenta and violet holographic shimmer',
    'glacier white with gunmetal and ice blue details',
    'sunset coral bleeding into indigo',
    'champagne gold over matte black',
    'arctic teal with copper circuitry lines',
    'oxblood red with black chrome trim',
    'electric lime cutting through graphite grey',
    'purple dusk gradient with silver flecks',
    'sand beige and olive with weathered edges',
    'molten silver with iridescent petrol sheen',
    'sky blue with white geometric pops',
  ];

  /// Patterns that read well on a car body when tiled and clipped to panels.
  static const List<String> patterns = [
    'angular digital camouflage blocks',
    'fine carbon fibre weave',
    'bold racing stripes sweeping front to back',
    'topographic contour lines',
    'shattered glass shards with crisp edges',
    'honeycomb hex grid',
    'retro wave grid with a horizon line',
    'marble veins with metallic inclusions',
    'scattered splatter droplets',
    'labyrinth of thin parallel lines',
    'camouflage blotches in three tones',
    'geometric triangle facets',
    'floral line art drawn with a single stroke',
    'circuit board traces and solder points',
    'ink wash clouds with hard edges',
    'pinstripe flames licking backwards',
  ];

  /// Surface finishes that change how the pattern is described.
  static const List<String> finishes = [
    'matte finish',
    'satin sheen',
    'glossy wet look',
    'soft-touch textured look',
    'brushed metal feel',
    'pearlescent shimmer',
  ];

  /// Extra atmosphere, used for about half of the ideas.
  static const List<String> moods = [
    'cyberpunk night energy',
    'vintage motorsport attitude',
    'quiet luxury',
    'brutalist industrial mood',
    'retro futuristic optimism',
    'storm chasing drama',
  ];

  /// Returns one idea for [style].
  ///
  /// The style is used as a hint too: a camo idea starts from the camo
  /// patterns, so the picker and the generated prompt never disagree.
  WrapIdea idea({WrapStyle? style}) {
    final chosenStyle = style ?? _pick(WrapStyle.presets);
    final patterns = _patternsFor(chosenStyle);

    final parts = <String>[
      _pick(palettes),
      _pick(patterns),
      _pick(finishes),
    ];
    if (_random.nextBool()) {
      parts.add(_pick(moods));
    }

    return WrapIdea(concept: parts.join(', '), style: chosenStyle);
  }

  /// Returns [count] ideas, each with its own randomly picked style.
  ///
  /// No two ideas in the list repeat a concept.
  List<WrapIdea> ideas({int count = 3}) {
    final result = <WrapIdea>[];
    final seen = <String>{};

    // Bounded loop: the pools are large enough for any sane [count], and a
    // duplicate would only ever cost one extra draw.
    var attempts = 0;
    while (result.length < count && attempts < count * 20) {
      attempts++;
      final idea = this.idea();
      if (seen.add(idea.concept)) result.add(idea);
    }
    return result;
  }

  /// The patterns that belong to [style], falling back to the whole pool.
  List<String> _patternsFor(WrapStyle style) {
    switch (style.id) {
      case 'camo':
        return const [
          'angular digital camouflage blocks',
          'camouflage blotches in three tones',
          'shattered glass shards with crisp edges',
        ];
      case 'gradient':
        return const [
          'marble veins with metallic inclusions',
          'ink wash clouds with hard edges',
          'retro wave grid with a horizon line',
        ];
      case 'retro':
        return const [
          'bold racing stripes sweeping front to back',
          'pinstripe flames licking backwards',
          'circuit board traces and solder points',
        ];
      case 'pixel':
        return const [
          'honeycomb hex grid',
          'geometric triangle facets',
          'labyrinth of thin parallel lines',
        ];
      case 'nature':
        return const [
          'topographic contour lines',
          'floral line art drawn with a single stroke',
          'marble veins with metallic inclusions',
        ];
      case 'space':
        return const [
          'scattered splatter droplets',
          'ink wash clouds with hard edges',
          'retro wave grid with a horizon line',
        ];
      case 'concrete':
        return const [
          'geometric triangle facets',
          'labyrinth of thin parallel lines',
          'camouflage blotches in three tones',
        ];
      default:
        return patterns;
    }
  }

  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];
}
