import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wrap_layer.dart';

/// Keeps the layer stacks of a session between page reloads.
///
/// The layers are small (text, brush points and a logo), so one JSON document
/// under a single key is enough. Designs live in memory only, which means a
/// stored stack is looked up by design id and simply never found again after a
/// reload: that is why the store also caps how many stacks it keeps.
class LayerStore {
  /// Creates a store.
  const LayerStore();

  static const String _key = 'design.layers';

  /// How many designs keep their layers.
  static const int maxDesigns = 12;

  /// Largest logo that is written to disk, in bytes.
  ///
  /// Local storage is a few megabytes for the whole origin; a 4 MB logo would
  /// fill it on its own and make every later write fail.
  static const int maxImageBytes = 1024 * 1024;

  /// Reads every stored stack.
  Future<Map<String, List<WrapLayer>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return {};

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};

      final result = <String, List<WrapLayer>>{};
      decoded.forEach((designId, value) {
        if (designId is! String || value is! List) return;
        final layers = <WrapLayer>[];
        for (final entry in value) {
          if (entry is! Map) continue;
          final layer = WrapLayer.fromJson(Map<String, dynamic>.from(entry));
          if (layer != null) layers.add(layer);
        }
        if (layers.isNotEmpty) result[designId] = layers;
      });
      return result;
    } on Object catch (error) {
      debugPrint('Could not read the stored layers: $error');
      return {};
    }
  }

  /// Writes the whole set.
  ///
  /// A stack with a logo that is too large is saved without the logo pixels
  /// rather than dropped: the text and the strokes survive, and the panel
  /// reports the logo as missing.
  Future<void> save(Map<String, List<WrapLayer>> stacks) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final trimmed = <String, List<Map<String, dynamic>>>{};
      final keys = stacks.keys.toList();
      // Newest designs are inserted first, so keep the head of the list.
      for (final designId in keys.take(maxDesigns)) {
        final layers = stacks[designId];
        if (layers == null || layers.isEmpty) continue;
        trimmed[designId] = [
          for (final layer in layers) _serialisable(layer),
        ];
      }

      if (trimmed.isEmpty) {
        await prefs.remove(_key);
        return;
      }
      await prefs.setString(_key, jsonEncode(trimmed));
    } on Object catch (error) {
      // Storage being full or blocked must not break the studio: the layers
      // stay in memory for the session.
      debugPrint('Could not store the layers: $error');
    }
  }

  /// Removes every stored stack.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Map<String, dynamic> _serialisable(WrapLayer layer) {
    final json = layer.toJson();
    final image = layer.imageBytes;
    if (image != null && image.length > maxImageBytes) {
      json.remove('image');
      json['name'] = '${layer.name} (logo not saved)';
    }
    return json;
  }
}
