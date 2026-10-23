import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_custom_wraps/services/prompt_builder.dart';
import 'package:tesla_custom_wraps/services/wrap_ideas.dart';

void main() {
  group('WrapIdeaGenerator', () {
    test('every idea is a full, promptable concept', () {
      final generator = WrapIdeaGenerator(random: Random(7));

      for (var i = 0; i < 200; i++) {
        final idea = generator.idea();
        expect(idea.concept.trim(), isNotEmpty);
        // A colour story, a pattern and a finish at least.
        expect(idea.concept.split(',').length, greaterThanOrEqualTo(3));
      }
    });

    test('ideas never name a vehicle', () {
      // Naming one, even to rule it out, makes an image model draw a car
      // instead of a pattern.
      final generator = WrapIdeaGenerator(random: Random(11));
      final forbidden = RegExp(
        r'\b(tesla|car|vehicle|cybertruck|model [3sxy]|sedan|suv|truck)\b',
        caseSensitive: false,
      );

      for (var i = 0; i < 300; i++) {
        expect(generator.idea().concept, isNot(matches(forbidden)));
      }
    });

    test('a style hint keeps the idea on that style', () {
      final generator = WrapIdeaGenerator(random: Random(3));

      for (var i = 0; i < 20; i++) {
        final idea = generator.idea(style: WrapStyle.byId('camo'));
        expect(idea.style.id, 'camo');
        expect(
          idea.concept,
          anyOf(
            contains('camouflage'),
            contains('glass shards'),
          ),
        );
      }
    });

    test('the batch is varied and free of duplicates', () {
      final generator = WrapIdeaGenerator(random: Random(5));
      final ideas = generator.ideas(count: 4);

      expect(ideas, hasLength(4));
      expect(ideas.map((idea) => idea.concept).toSet(), hasLength(4));
    });

    test('a seeded generator is reproducible', () {
      final first = WrapIdeaGenerator(random: Random(42)).idea();
      final second = WrapIdeaGenerator(random: Random(42)).idea();
      expect(first.concept, second.concept);
    });
  });

  group('prompt without user input', () {
    test('an empty concept still builds a complete prompt', () {
      final prompt = WrapPromptBuilder.build(
        concept: '',
        vehicleName: 'Model 3',
        style: WrapStyle.defaultStyleHint,
      );
      expect(prompt, contains('invent a striking wrap'));
      expect(prompt, contains('OUTPUT CONTRACT'));
    });

    test('an invented concept reaches the prompt verbatim', () {
      final idea = WrapIdeaGenerator(random: Random(1)).idea();
      final prompt = WrapPromptBuilder.build(
        concept: idea.concept,
        vehicleName: 'Model Y',
        style: idea.style.hint,
      );
      expect(prompt, contains(idea.concept));
    });
  });
}
