import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tesla_custom_wraps/services/glb_texture_patch.dart';
import 'package:tesla_custom_wraps/services/vehicle_viewer.dart';
import 'package:tesla_custom_wraps/services/vehicle_service.dart';

/// Builds a minimal GLB with one paint material and one trim material.
Uint8List _tinyGlb() {
  final json = {
    'asset': {'version': '2.0'},
    'scenes': [
      {'nodes': [0]},
    ],
    'scene': 0,
    'nodes': [
      {'mesh': 0},
    ],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'material': 0,
          },
        ],
      },
    ],
    'materials': [
      {
        'name': 'carpaint',
        'pbrMetallicRoughness': {'baseColorFactor': [1, 0, 0, 1]},
      },
      {
        'name': 'glass',
        'pbrMetallicRoughness': {'baseColorFactor': [0, 0, 1, 1]},
      },
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'max': [1, 1, 1],
        'min': [0, 0, 0],
      },
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
    ],
    'buffers': [
      {'byteLength': 36},
    ],
  };

  final jsonBytes = utf8.encode(jsonEncode(json));
  final paddedJson = [
    ...jsonBytes,
    for (var i = 0; i < (4 - jsonBytes.length % 4) % 4; i++) 0x20,
  ];
  final bin = List<int>.generate(36, (i) => 0);
  final total = 12 + 8 + paddedJson.length + 8 + bin.length;

  final out = Uint8List(total);
  final data = ByteData.sublistView(out);
  data.setUint32(0, 0x46546C67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, total, Endian.little);
  data.setUint32(12, paddedJson.length, Endian.little);
  data.setUint32(16, 0x4E4F534A, Endian.little);
  out.setRange(20, 20 + paddedJson.length, paddedJson);
  final binHeader = 20 + paddedJson.length;
  data.setUint32(binHeader, bin.length, Endian.little);
  data.setUint32(binHeader + 4, 0x004E4942, Endian.little);
  out.setRange(binHeader + 8, binHeader + 8 + bin.length, bin);
  return out;
}

Map<String, dynamic> _json(Uint8List glb) {
  final data = ByteData.sublistView(glb);
  final length = data.getUint32(12, Endian.little);
  final start = 20;
  return jsonDecode(utf8.decode(glb.sublist(start, start + length)))
      as Map<String, dynamic>;
}

void main() {
  group('GlbMaterialOverride', () {
    test('recognises the paint materials of the shipped models', () {
      expect(GlbMaterialOverride.isPaintMaterial('carpaint'), isTrue);
      expect(GlbMaterialOverride.isPaintMaterial('Carro_Pintura'), isTrue);
      expect(GlbMaterialOverride.isPaintMaterial('Bodyl'), isTrue);
      expect(GlbMaterialOverride.isPaintMaterial('glass'), isFalse);
      expect(GlbMaterialOverride.isPaintMaterial('Tire'), isFalse);
      expect(GlbMaterialOverride.isPaintMaterial('Carro_Pneu'), isFalse);
    });

    test('adds a texture and points the paint material at it', () {
      final glb = _tinyGlb();
      final texture = img.encodePng(
        img.Image(width: 4, height: 4, numChannels: 4),
      );

      final patched = GlbMaterialOverride.applyWrapTexture(
        glb,
        texture: texture,
        mimeType: 'image/png',
      );

      expect(patched, isNotNull);

      final json = _json(patched!);
      expect(json['images'], hasLength(1));
      expect(json['textures'], hasLength(1));
      expect(json['samplers'], hasLength(1));

      final paint = (json['materials'] as List).first as Map;
      final pbr = paint['pbrMetallicRoughness'] as Map;
      expect(pbr['baseColorTexture'], isNotNull);
      expect((pbr['baseColorTexture'] as Map)['index'], 0);

      // The trim material keeps its own colour.
      final trim = (json['materials'] as List)[1] as Map;
      expect(
        (trim['pbrMetallicRoughness'] as Map)['baseColorTexture'],
        isNull,
      );

      // The image is reachable through the binary chunk.
      final view = (json['bufferViews'] as List).last as Map;
      expect(view['byteLength'], texture.length);
      expect(
        (json['buffers'] as List).first as Map,
        containsPair('byteLength', greaterThan(texture.length)),
      );
    });

    test('keeps the rest of the model intact', () {
      final glb = _tinyGlb();
      final patched = GlbMaterialOverride.applyWrapTexture(
        glb,
        texture: img.encodePng(
          img.Image(width: 2, height: 2, numChannels: 4),
        ),
        mimeType: 'image/png',
      )!;

      final before = _json(glb);
      final after = _json(patched);
      expect(after['meshes'], before['meshes']);
      expect(after['accessors'], before['accessors']);
      expect((after['materials'] as List).length, 2);
    });

    test('rejects input that is not a GLB', () {
      expect(
        GlbMaterialOverride.applyWrapTexture(
          Uint8List.fromList([1, 2, 3, 4]),
          texture: Uint8List(4),
          mimeType: 'image/png',
        ),
        isNull,
      );
    });

    test('reports the paint materials of the real models', () {
      // The five compressed models in web/models/ drive the 3D preview.
      final directory = Directory('web/models');
      if (!directory.existsSync()) return;

      for (final file in directory.listSync().whereType<File>()) {
        if (!file.path.endsWith('.glb')) continue;
        final materials =
            GlbMaterialOverride.paintMaterials(file.readAsBytesSync());
        expect(
          materials,
          isNotEmpty,
          reason: '${file.path} has no paintable material',
        );
      }
    });
  });

  group('vehicleModelUrl', () {
    test('serves every model from the compressed web folder', () {
      for (final vehicle in VehicleService.getVehicles()) {
        final url = vehicleModelUrl(vehicle);
        if (vehicle.glbPath == null) {
          expect(url, isNull);
          continue;
        }
        expect(url, startsWith('models/'));
        // The model that is actually deployed has to exist in the repository.
        final file = File('web/$url');
        expect(
          file.existsSync(),
          isTrue,
          reason: '${vehicle.id} points at a missing ${file.path}',
        );
      }
    });

    test('the compressed models are small enough to deploy', () {
      final files = Directory('web/models')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.glb'));

      var total = 0;
      for (final file in files) {
        total += file.lengthSync();
      }
      expect(files, isNotEmpty);
      // 117 MB of originals have to stay well under the Pages limits.
      expect(total, lessThan(15 * 1024 * 1024));
    });
  });

  group('encodeViewerTexture', () {
    test('produces a square, opaque PNG', () {
      final artwork = img.Image(width: 200, height: 100, numChannels: 4);
      img.fill(artwork, color: img.ColorRgba8(10, 20, 30, 0));
      final encoded = encodeViewerTexture(img.encodePng(artwork));

      final decoded = img.decodePng(encoded)!;
      expect(decoded.width, decoded.height);
      expect(decoded.getPixel(4, 4).a, 255);
    });
  });
}
