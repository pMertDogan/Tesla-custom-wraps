import 'dart:convert';
import 'dart:typed_data';

/// Rewrites the material of a GLB so it carries a custom wrap texture.
///
/// The viewer needs one thing from a vehicle model that glTF does not let us
/// change from outside: a texture on the painted body. A `model-viewer`
/// `<model-viewer>` element cannot be told "paint this material red", so the
/// studio does the equivalent of opening the file in an editor:
///
/// 1. a WebP or PNG of the wrap is appended to the binary chunk,
/// 2. a buffer view, an image, a sampler and a texture are added to the JSON
///    chunk, all pointing at those new bytes,
/// 3. every material whose name marks it as car paint gets a
///    `baseColorTexture` pointing at the new texture, tiled by the tiling
///    factors the wrap needs.
///
/// The result is a valid GLB that `model-viewer` loads like any other. Nothing
/// outside the body paint changes: glass, tyres, lights and chrome keep their
/// own materials, which is what keeps the preview readable.
class GlbMaterialOverride {
  const GlbMaterialOverride._();

  /// Largest wrap texture edge the preview accepts.
  ///
  /// The exported wrap is at most 1024 px and the texture travels as base64
  /// through the DOM bridge, so this is also the practical limit for a
  /// responsive preview.
  static const int maxTextureEdge = 1024;

  /// Names (lower case, matched as substrings) of the materials that carry
  /// the car paint.
  ///
  /// The five models in the repository do not agree on material names: the
  /// Model 3 calls its paint `carpaint`, the Model Y calls it `Carro_Pintura`
  /// and the Cybertruck calls it `Bodyl`. Everything else in those files is
  /// trim.
  static const List<String> paintMaterialNames = [
    'carpaint',
    'carro_pintura',
    'bodyl',
    'body_',
    'paint',
    'exterior',
  ];

  /// Material names that are trim rather than paint.
  ///
  /// Only used for the models whose materials are all named generically
  /// (`Material_2125767099`, `black222`, …): there the painted body is the
  /// largest surface that is not obviously glass, rubber or a light.
  static const List<String> trimMaterialNames = [
    'glass',
    'light',
    'lamp',
    'rubber',
    'tire',
    'tyre',
    'wheel',
    'rim',
    'brake',
    'break',
    'chrome',
    'mirror',
    'plate',
    'brand',
    'logo',
    'badge',
    'interior',
    'leather',
    'wood',
    'seat',
    'screen',
    'plastic',
    'emblem',
  ];

  /// Whether [materialName] looks like the painted body of a car.
  static bool isPaintMaterial(String materialName) {
    final lower = materialName.toLowerCase();
    if (isTrimMaterial(lower)) return false;
    for (final name in paintMaterialNames) {
      if (lower.contains(name)) return true;
    }
    return false;
  }

  /// Whether [materialName] names trim that never carries a wrap.
  static bool isTrimMaterial(String materialName) {
    final lower = materialName.toLowerCase();
    for (final name in trimMaterialNames) {
      if (lower.contains(name)) return true;
    }
    return false;
  }

  /// Merges a base colour texture into [glb].
  ///
  /// [texture] is the encoded image (WebP or PNG). [uvScale] repeats the wrap
  /// across the body panels: the model's UV set is not Tesla's atlas, so the
  /// preview shows the wrap pattern rather than an exact panel placement.
  ///
  /// Returns `null` when [glb] is not a GLB that can be rewritten. A caller
  /// that gets `null` should show the model without a wrap instead of failing.
  static Uint8List? applyWrapTexture(
    Uint8List glb, {
    required Uint8List texture,
    required String mimeType,
    double uvScale = 1,
  }) {
    final parsed = _Glb.parse(glb);
    if (parsed == null) return null;

    final json = parsed.json;

    // Index of the first byte of the new image inside the binary chunk.
    final imageOffset = parsed.bin.length;
    // glTF requires buffer view offsets to be 4 byte aligned.
    final padding = (4 - (imageOffset % 4)) % 4;

    final bufferViews = _listOfMaps(json, 'bufferViews');
    final images = _listOfMaps(json, 'images');
    final textures = _listOfMaps(json, 'textures');
    final samplers = _listOfMaps(json, 'samplers');
    final materials = _listOfMaps(json, 'materials');

    final bufferViewIndex = bufferViews.length;
    bufferViews.add({
      'buffer': 0,
      'byteOffset': imageOffset,
      'byteLength': texture.length,
    });

    final imageIndex = images.length;
    images.add({
      'bufferView': bufferViewIndex,
      'mimeType': mimeType,
    });

    final samplerIndex = samplers.length;
    samplers.add({
      'magFilter': 9729, // LINEAR
      'minFilter': 9987, // LINEAR_MIPMAP_LINEAR
      'wrapS': 10497, // REPEAT
      'wrapT': 10497,
    });

    final textureIndex = textures.length;
    textures.add({
      'sampler': samplerIndex,
      'source': imageIndex,
    });

    final indices = paintMaterialIndices(json);
    var painted = 0;
    for (final index in indices) {
      if (index < 0 || index >= materials.length) continue;
      final material = materials[index];

      final pbr = material.putIfAbsent(
        'pbrMetallicRoughness',
        () => <String, dynamic>{},
      );
      if (pbr is! Map<String, dynamic>) continue;

      pbr['baseColorTexture'] = {
        'index': textureIndex,
        'texCoord': 0,
      };
      // A metal panel would darken the pattern and a glossy one would turn it
      // into a mirror; the preview wants the artwork itself.
      pbr['metallicFactor'] = 0.05;
      pbr['roughnessFactor'] = 0.55;
      if (uvScale != 1) {
        // Metallic-roughness textures and the base colour share the transform
        // only when it lives on the texture info, which older viewers ignore
        // for base colour. The scale is applied through KHR_texture_transform
        // when the caller needs it.
        pbr['baseColorTexture'] = {
          'index': textureIndex,
          'texCoord': 0,
          'extensions': {
            'KHR_texture_transform': {
              'scale': [uvScale, uvScale],
              'offset': [0, 0],
            },
          },
        };
        final extensionsUsed = json['extensionsUsed'];
        if (extensionsUsed is List) {
          if (!extensionsUsed.contains('KHR_texture_transform')) {
            extensionsUsed.add('KHR_texture_transform');
          }
        } else {
          json['extensionsUsed'] = ['KHR_texture_transform'];
        }
      }
      painted++;
    }

    if (painted == 0) return null;

    final bin = Uint8List(imageOffset + padding + texture.length)
      ..setRange(0, imageOffset, parsed.bin)
      ..setRange(imageOffset + padding, imageOffset + padding + texture.length,
          texture);

    // The buffer entry has to cover the new bytes as well.
    final buffers = _listOfMaps(json, 'buffers');
    if (buffers.isEmpty) {
      buffers.add({'byteLength': bin.length});
    } else {
      buffers.first['byteLength'] = bin.length;
    }

    return _Glb.encode(json, bin);
  }

  /// The material indices that carry the car paint.
  ///
  /// Two strategies, in order:
  ///
  /// 1. **By name.** The Model 3, the 2021 Model Y and the Cybertruck name
  ///    their paint (`carpaint`, `Carro_Pintura`, `Bodyl`).
  /// 2. **By surface.** The 2025 and 2026 Model Y call everything
  ///    `Material_2125767099`, `black222`, … and have no node names to go by.
  ///    There the painted body is taken to be the largest surfaces that are
  ///    not trim, up to roughly a third of the mesh.
  static List<int> paintMaterialIndices(Map<String, dynamic> json) {
    final materials = json['materials'];
    if (materials is! List || materials.isEmpty) return const [];

    final named = <int>[];
    final generic = <int>[];
    for (var i = 0; i < materials.length; i++) {
      final material = materials[i];
      if (material is! Map) continue;
      final name = material['name'];
      if (name is! String) continue;
      if (isPaintMaterial(name)) {
        named.add(i);
      } else if (!isTrimMaterial(name)) {
        generic.add(i);
      }
    }
    if (named.isNotEmpty) return named;
    if (generic.isEmpty) return const [];

    final weights = _vertexCountsPerMaterial(json);
    var total = 0;
    for (final value in weights.values) {
      total += value;
    }
    if (total == 0) return const [generic.first];

    generic.sort((a, b) => (weights[b] ?? 0).compareTo(weights[a] ?? 0));

    final selected = <int>[];
    var covered = 0;
    for (final index in generic) {
      selected.add(index);
      covered += weights[index] ?? 0;
      if (selected.length >= 4 || covered >= total * 0.35) break;
    }
    return selected;
  }

  /// Sum of the position counts of every primitive that uses each material.
  static Map<int, int> _vertexCountsPerMaterial(Map<String, dynamic> json) {
    final accessors = json['accessors'];
    final meshes = json['meshes'];
    if (accessors is! List || meshes is! List) return const {};

    final counts = <int, int>{};
    for (final mesh in meshes) {
      if (mesh is! Map) continue;
      final primitives = mesh['primitives'];
      if (primitives is! List) continue;

      for (final primitive in primitives) {
        if (primitive is! Map) continue;
        final material = primitive['material'];
        if (material is! int) continue;

        final attributes = primitive['attributes'];
        if (attributes is! Map) continue;
        final position = attributes['POSITION'];
        if (position is! int || position >= accessors.length) continue;

        final accessor = accessors[position];
        if (accessor is! Map) continue;
        final count = accessor['count'];
        if (count is! int) continue;

        counts[material] = (counts[material] ?? 0) + count;
      }
    }
    return counts;
  }

  /// Returns the material names that carry the paint.
  ///
  /// Used by the studio to say whether a model can show a wrap at all, and by
  /// the tests to check the five shipped models.
  static List<String> paintMaterials(Uint8List glb) {
    final parsed = _Glb.parse(glb);
    if (parsed == null) return const [];
    final materials = parsed.json['materials'];
    if (materials is! List) return const [];

    return [
      for (final index in paintMaterialIndices(parsed.json))
        if (index < materials.length &&
            materials[index] is Map &&
            (materials[index] as Map)['name'] is String)
          (materials[index] as Map)['name'] as String,
    ];
  }

  static List<Map<String, dynamic>> _listOfMaps(
    Map<String, dynamic> json,
    String key,
  ) {
    final existing = json[key];
    if (existing is List && existing.every((e) => e is Map)) {
      return existing.cast<Map<String, dynamic>>();
    }
    final created = <Map<String, dynamic>>[];
    json[key] = created;
    return created;
  }
}

/// A parsed GLB container.
class _Glb {
  const _Glb({required this.json, required this.bin});

  final Map<String, dynamic> json;
  final Uint8List bin;

  static const int _magic = 0x46546C67; // 'glTF'
  static const int _jsonChunk = 0x4E4F534A; // 'JSON'
  static const int _binChunk = 0x004E4942; // 'BIN'

  /// Reads the JSON and binary chunks of [bytes].
  ///
  /// Returns `null` for anything that is not a GLB 2.0 container, so a broken
  /// download never throws in the middle of a generation.
  static _Glb? parse(Uint8List bytes) {
    if (bytes.length < 20) return null;
    final data = ByteData.sublistView(bytes);

    if (data.getUint32(0, Endian.little) != _magic) return null;
    if (data.getUint32(4, Endian.little) != 2) return null;

    final totalLength = data.getUint32(8, Endian.little);
    var offset = 12;
    Map<String, dynamic>? json;
    Uint8List? bin;

    while (offset + 8 <= totalLength && offset + 8 <= bytes.length) {
      final chunkLength = data.getUint32(offset, Endian.little);
      final chunkType = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      final end = start + chunkLength;
      if (end > bytes.length) return null;

      if (chunkType == _jsonChunk && json == null) {
        try {
          final decoded = _decodeJson(bytes.sublist(start, end));
          if (decoded is! Map<String, dynamic>) return null;
          json = decoded;
        } on FormatException {
          return null;
        }
      } else if (chunkType == _binChunk && bin == null) {
        bin = Uint8List.sublistView(bytes, start, end);
      }

      // Chunks are padded to a multiple of four bytes.
      offset = end + ((4 - (chunkLength % 4)) % 4);
    }

    if (json == null) return null;
    return _Glb(json: json, bin: bin ?? Uint8List(0));
  }

  /// Writes [json] and [bin] back into a GLB container.
  static Uint8List encode(Map<String, dynamic> json, Uint8List bin) {
    final jsonBytes = Uint8List.fromList(
      // The JSON chunk may be padded with spaces, the BIN chunk with zeroes.
      _padRight(utf8.encode(jsonEncode(json)), 0x20),
    );
    final binBytes = Uint8List.fromList(_padRight(bin, 0x00));

    final totalLength = 12 + 8 + jsonBytes.length + 8 + binBytes.length;
    final out = Uint8List(totalLength);
    final data = ByteData.sublistView(out);

    data.setUint32(0, _magic, Endian.little);
    data.setUint32(4, 2, Endian.little);
    data.setUint32(8, totalLength, Endian.little);

    data.setUint32(12, jsonBytes.length, Endian.little);
    data.setUint32(16, _jsonChunk, Endian.little);
    out.setRange(20, 20 + jsonBytes.length, jsonBytes);

    final binHeader = 20 + jsonBytes.length;
    data.setUint32(binHeader, binBytes.length, Endian.little);
    data.setUint32(binHeader + 4, _binChunk, Endian.little);
    out.setRange(binHeader + 8, binHeader + 8 + binBytes.length, binBytes);

    return out;
  }

  static List<int> _padRight(Uint8List bytes, int fill) {
    final padding = (4 - (bytes.length % 4)) % 4;
    if (padding == 0) return bytes;
    return [
      ...bytes,
      for (var i = 0; i < padding; i++) fill,
    ];
  }

  static Object? _decodeJson(Uint8List bytes) {
    // The JSON chunk is padded with spaces; `jsonDecode` tolerates them.
    var end = bytes.length;
    while (end > 0 && (bytes[end - 1] == 0x20 || bytes[end - 1] == 0x00)) {
      end--;
    }
    return jsonDecode(utf8.decode(Uint8List.sublistView(bytes, 0, end)));
  }
}
