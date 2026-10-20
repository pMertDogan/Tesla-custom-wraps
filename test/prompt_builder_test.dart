import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_custom_wraps/services/prompt_builder.dart';

void main() {
  group('WrapPromptBuilder', () {
    test('keeps the user concept in the prompt', () {
      final prompt = WrapPromptBuilder.build(
        concept: 'Midnight blue carbon fibre with cyan racing stripes',
        vehicleName: 'Model Y',
      );

      expect(
        prompt,
        contains('Midnight blue carbon fibre with cyan racing stripes'),
      );
      expect(prompt, contains('Model Y'));
    });

    test('demands a flat texture instead of a car render', () {
      final prompt = WrapPromptBuilder.build(
        concept: 'red flames',
        vehicleName: 'Cybertruck',
      );

      expect(prompt, contains('flat 2D texture sheet'));
      expect(prompt, contains('Never draw the car itself'));
      expect(prompt, contains('No text'));
    });

    test('asks the model to respect the attached UV atlas', () {
      final prompt = WrapPromptBuilder.build(
        concept: 'red flames',
        vehicleName: 'Model 3',
        hasReferenceTemplate: true,
      );

      expect(prompt, contains('reference image is the exact UV atlas'));
      expect(prompt, contains('white (paintable) areas'));
    });

    test('describes the layout in text when there is no reference image', () {
      final prompt = WrapPromptBuilder.build(
        concept: 'red flames',
        vehicleName: 'Model 3',
        hasReferenceTemplate: false,
      );

      expect(prompt, contains('square texture atlas'));
      expect(prompt, isNot(contains('reference image is the exact UV atlas')));
    });

    test('appends the selected style', () {
      final prompt = WrapPromptBuilder.build(
        concept: 'red flames',
        vehicleName: 'Model 3',
        style: WrapStyle.byId('camo').hint,
      );

      expect(prompt, contains('digital camouflage'));
    });

    test('falls back to an invented design when the prompt is empty', () {
      final prompt = WrapPromptBuilder.build(
        concept: '   ',
        vehicleName: 'Model 3',
      );

      expect(prompt, contains('invent a striking wrap'));
    });

    test('collapses whitespace and clips long concepts', () {
      final concept = List.filled(2000, 'flame').join(' ');

      final prompt = WrapPromptBuilder.build(
        concept: concept,
        vehicleName: 'Model 3',
      );

      expect(
        WrapPromptBuilder.sanitizeConcept(concept).length,
        lessThanOrEqualTo(WrapPromptBuilder.maxConceptLength),
      );
      expect(prompt, isNot(contains('  ')));
    });

    test('asks for a flat pattern when the provider ignores the layout', () {
      final prompt = WrapPromptBuilder.build(
        concept: 'midnight blue carbon fibre',
        vehicleName: 'Model 3',
        flatPatternOnly: true,
      );

      expect(prompt, contains('midnight blue carbon fibre'));
      expect(prompt, contains('seamless abstract texture pattern'));
      expect(prompt, contains('edge to edge'));
      // The panel layout is handled by the mask, so it is not described.
      expect(prompt, isNot(contains('UV atlas')));
      expect(prompt, isNot(contains('Paint Shop template')));
    });

    test('never names a vehicle in a pattern prompt', () {
      // Naming a car, even to rule it out, is enough to make an image model
      // render one, and a wrap that shows a photo of a car is worthless.
      for (final concept in [
        'a red car wrap',
        'a cybertruck wrap',
        'a tesla wrap',
        'a model 3 wrap',
        'a vehicle wrap',
        'a truck wrap',
      ]) {
        final prompt = WrapPromptBuilder.buildPattern(concept: concept);
        for (final word in ['car', 'vehicle', 'cybertruck', 'tesla', 'truck']) {
          expect(
            RegExp(r'\b$word\b', caseSensitive: false).hasMatch(prompt),
            isFalse,
            reason: '$concept kept "$word"',
          );
        }
      }
    });

    test('keeps the pattern prompt short enough for a URL', () {
      final prompt = WrapPromptBuilder.buildPattern(
        concept: 'x' * 200,
        style: 'Crisp vector-like graphics.',
      );

      expect(prompt.length, lessThan(900));
    });

    test('invents a pattern when no concept is given', () {
      final prompt = WrapPromptBuilder.buildPattern(concept: '   ');

      expect(prompt, contains('invent a striking texture pattern'));
    });

    test('drops the vehicle from a pattern prompt', () {
      final prompt = WrapPromptBuilder.buildPattern(
        concept: 'a red cybertruck wrap with electric blue shards',
      );

      // The model would draw the truck instead of the wrap.
      expect(prompt, isNot(contains('cybertruck')));
      expect(prompt, isNot(contains('truck')));
      // The rest of the concept survives.
      expect(prompt, contains('electric blue shards'));
    });

    test('drops every model name from a pattern prompt', () {
      for (final vehicle in [
        'tesla',
        'model 3',
        'model s',
        'model x',
        'model y',
        'model l',
        'cybertruck',
      ]) {
        final cleaned = WrapPromptBuilder.sanitizePatternConcept(
          'wrap for the $vehicle in red',
        );
        expect(cleaned.contains(vehicle.toLowerCase()), isFalse, reason: vehicle);
        expect(cleaned, contains('red'));
      }
    });

    test('keeps words that merely look like a model name', () {
      expect(
        WrapPromptBuilder.sanitizePatternConcept('a model of behaviour'),
        'a model of behaviour',
      );
      expect(
        WrapPromptBuilder.sanitizePatternConcept('modelled in brass'),
        'modelled in brass',
      );
    });
  });

  group('WrapStyle', () {
    test('every preset has a unique id', () {
      final ids = WrapStyle.presets.map((style) => style.id).toSet();
      expect(ids.length, WrapStyle.presets.length);
    });

    test('falls back to the first preset for an unknown id', () {
      expect(WrapStyle.byId('does-not-exist').id, WrapStyle.presets.first.id);
    });
  });
}
