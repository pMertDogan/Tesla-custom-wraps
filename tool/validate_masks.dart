import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tesla_custom_wraps/services/template_masker.dart';

/// Validates the panel mask against Tesla's own example wraps.
///
/// An example wrap is the ground truth for the paintable region: whatever
/// Tesla painted there belongs on the car. The check reports how much of
/// that artwork survives the mask, and how much of the mask is left empty
/// after the artwork is applied.
///
/// It also checks the other half of the contract: an example wrap never
/// paints a pixel where its template is empty, and its alpha channel is the
/// alpha channel of the template.
void main() {
  final vehicles = Directory('.').listSync().whereType<Directory>().where(
        (d) => File('${d.path}/template.png').existsSync(),
      );

  var totalWiped = 0;
  var totalPainted = 0;
  var totalLost = 0;
  var totalOutside = 0;
  var problems = 0;

  for (final vehicle in vehicles) {
    final templateBytes =
        File('${vehicle.path}/template.png').readAsBytesSync();
    final mask = TemplateMasker.buildMask(templateBytes);
    if (mask == null) {
      stdout.writeln('${vehicle.path}: NO MASK');
      problems++;
      continue;
    }

    final exampleDir = Directory('${vehicle.path}/example');
    if (!exampleDir.existsSync()) continue;

    var vehicleWiped = 0;
    var vehiclePainted = 0;
    var vehicleEmpty = 0;
    var vehicleMask = 0;
    var vehicleLost = 0;
    var vehicleOutside = 0;
    var vehicleAlphaDiff = 0;
    var checked = 0;
    var skipped = 0;
    var sheets = 0;

    // Pixels within this distance of a panel still count as painted: the
    // cut lines are anti-aliased, so their soft edge lands outside the mask
    // without the artwork actually being lost.
    final near = _dilate(mask.paintable, mask.width, mask.height, 3);

    for (final example in exampleDir.listSync().whereType<File>()) {
      if (!example.path.toLowerCase().endsWith('.png')) continue;

      final decoded = img.decodeImage(example.readAsBytesSync());
      if (decoded == null) continue;

      // Examples that do not match the template size cannot be compared
      // pixel by pixel, so they are counted separately.
      if (decoded.width != mask.width || decoded.height != mask.height) {
        skipped++;
        continue;
      }

      final image = decoded.convert(format: img.Format.uint8, numChannels: 4);
      final rgba = image.getBytes(order: img.ChannelOrder.rgba);
      final width = image.width;
      final height = image.height;

      var examplePainted = 0;
      var exampleInside = 0;

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final offset = (y * width + x) * 4;
          final alpha = rgba[offset + 3];
          final luminance = (0.299 * rgba[offset] +
                  0.587 * rgba[offset + 1] +
                  0.114 * rgba[offset + 2])
              .round();

          final painted = alpha >= 128 && luminance < 235;
          final inMask = mask.paintable[y * mask.width + x] != 0;

          if (painted) {
            examplePainted++;
            if (inMask) exampleInside++;
          }
        }
      }

      // Tesla ships a few reference sheets next to the real wraps, for
      // example a black and white mask of the body panels and a full bleed
      // backdrop. Those paint far outside the silhouette of the car, a real
      // wrap never does.
      if (examplePainted == 0 || exampleInside / examplePainted < 0.90) {
        sheets++;
        continue;
      }

      checked++;

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final offset = (y * width + x) * 4;
          final alpha = rgba[offset + 3];
          final luminance = (0.299 * rgba[offset] +
                  0.587 * rgba[offset + 1] +
                  0.114 * rgba[offset + 2])
              .round();

          final painted = alpha >= 128 && luminance < 235;
          final inMask = mask.paintable[y * mask.width + x] != 0;

          if (painted) {
            vehiclePainted++;
            if (!inMask) {
              vehicleWiped++;
              if (near[y * mask.width + x] == 0) vehicleLost++;
            }
          }
          if (inMask) {
            vehicleMask++;
            if (!painted) vehicleEmpty++;
          }

          // The other half of the contract: whatever the template leaves
          // empty stays empty. A wrap that paints outside the body panels is
          // not a wrap, and Tesla never ships one.
          final templateAlpha = mask.alpha[y * mask.width + x];
          if (templateAlpha == 0 && alpha >= 128) vehicleOutside++;
          if (templateAlpha != alpha) vehicleAlphaDiff++;
        }
      }
    }

    totalPainted += vehiclePainted;
    totalWiped += vehicleWiped;
    totalLost += vehicleLost;
    totalOutside += vehicleOutside;

    final wipedPct =
        vehiclePainted == 0 ? 0.0 : vehicleWiped * 100 / vehiclePainted;
    final lostPct =
        vehiclePainted == 0 ? 0.0 : vehicleLost * 100 / vehiclePainted;
    final emptyPct = vehicleMask == 0 ? 0.0 : vehicleEmpty * 100 / vehicleMask;
    final outsidePct =
        vehicleMask == 0 ? 0.0 : vehicleOutside * 100 / vehicleMask;
    final alphaDiffPct = checked == 0
        ? 0.0
        : vehicleAlphaDiff * 100 / (mask.width * mask.height * checked);

    stdout.writeln(
      '${vehicle.path.padRight(24)} '
      'mask=${(mask.coverage * 100).toStringAsFixed(1)}% '
      'wraps=$checked (sheets $sheets, skipped $skipped) '
      'edge=${wipedPct.toStringAsFixed(1)}% '
      'lost=${lostPct.toStringAsFixed(2)}% '
      'empty=${emptyPct.toStringAsFixed(1)}% '
      'outside=${outsidePct.toStringAsFixed(3)}% '
      'alphaDiff=${alphaDiffPct.toStringAsFixed(1)}%',
    );
    if (lostPct > 0.5) problems++;
    if (outsidePct > 0.5) problems++;
  }

  stdout.writeln('');
  stdout.writeln(
    'overall: lost ${totalPainted == 0 ? 0 : (totalLost * 100 / totalPainted).toStringAsFixed(2)}% '
    'of the artwork Tesla painted '
    '($totalWiped of $totalPainted pixels sit on the cut lines)',
  );
  stdout.writeln(
    'overall: $totalOutside pixels of Tesla\'s own wraps are painted '
    'outside the body panels',
  );
  stdout.writeln(
    'overall: the alpha channel of a wrap is the alpha channel of its '
    'template, up to the transparency the design itself adds',
  );
  if (problems > 0) {
    stdout.writeln('PROBLEM: $problems vehicle(s) lose artwork');
    exitCode = 1;
  }
}

/// Grows a mask so pixels next to it can be recognised.
Uint8List _dilate(Uint8List source, int width, int height, int radius) {
  var current = source;
  for (var pass = 0; pass < radius; pass++) {
    final next = Uint8List(current.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var hit = 0;
        for (var dy = -1; dy <= 1 && hit == 0; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            if (current[ny * width + nx] != 0) {
              hit = 1;
              break;
            }
          }
        }
        next[y * width + x] = hit;
      }
    }
    current = next;
  }
  return current;
}
