import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_custom_wraps/services/vehicle_service.dart';

void main() {
  group('VehicleService', () {
    test('ships every vehicle Tesla publishes a template for', () {
      expect(VehicleService.getVehicles(), hasLength(12));
    });

    test('ids are unique', () {
      final ids = VehicleService.getVehicles().map((v) => v.id).toSet();
      expect(ids.length, VehicleService.getVehicles().length);
    });

    test('every vehicle points at files that exist', () {
      for (final vehicle in VehicleService.getVehicles()) {
        expect(
          File(vehicle.templatePath).existsSync(),
          isTrue,
          reason: 'missing template for ${vehicle.id}',
        );
        expect(
          File(vehicle.imagePath).existsSync(),
          isTrue,
          reason: 'missing vehicle image for ${vehicle.id}',
        );
        expect(
          vehicle.exampleNames,
          isNotEmpty,
          reason: '${vehicle.id} has no example wraps',
        );
        for (final example in vehicle.exampleNames) {
          expect(
            File('${vehicle.folder}/example/$example').existsSync(),
            isTrue,
            reason: 'missing example $example for ${vehicle.id}',
          );
        }
      }
    });

    test('example wrap lists match the folders on disk', () {
      for (final vehicle in VehicleService.getVehicles()) {
        final onDisk = Directory('${vehicle.folder}/example')
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toSet();
        expect(
          onDisk.difference(vehicle.exampleNames.toSet()),
          isEmpty,
          reason: '${vehicle.id} lists examples that are not on disk',
        );
      }
    });

    test('template sizes stay inside the range Tesla accepts', () {
      for (final vehicle in VehicleService.getVehicles()) {
        expect(vehicle.templateWidth, lessThanOrEqualTo(1024));
        expect(vehicle.templateHeight, lessThanOrEqualTo(1024));
        expect(vehicle.templateWidth, greaterThanOrEqualTo(512));
        expect(vehicle.templateHeight, greaterThanOrEqualTo(512));
      }
    });

    test('findById resolves known ids and rejects unknown ones', () {
      expect(VehicleService.findById('model3')?.name, 'Model 3');
      expect(VehicleService.findById('nope'), isNull);
    });

    test('the global example list covers every vehicle', () {
      final total = VehicleService.getVehicles()
          .fold<int>(0, (sum, vehicle) => sum + vehicle.exampleCount);
      expect(VehicleService.allExampleWrapPaths, hasLength(total));
    });
  });
}
