import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:store_app/data/local_asset_store.dart';
import 'package:store_app/application/processing_service.dart';

void main() {
  test('import stores a real decoded image and rejects traversal and invalid files', () async {
    final dir = await Directory.systemTemp.createTemp('bootic-assets-');
    try {
      final store = LocalAssetStore(Directory('${dir.path}/private'));
      final source = File('${dir.path}/source.png');
      final image = img.Image(width: 128, height: 100);
      img.fill(image, color: img.ColorRgb8(20, 80, 150));
      await source.writeAsBytes(img.encodePng(image));
      final relative = await store.importPhoto(source.path);
      await source.delete();
      final decoded = img.decodeJpg(await store.resolve(relative).readAsBytes())!;
      expect(decoded.width, 128);
      expect(decoded.height, 100);
      expect(decoded.getPixel(64, 50).b, greaterThan(140));
      expect(() => store.resolve('../outside.jpg'), throwsArgumentError);
      final invalid = File('${dir.path}/fake.jpg');
      await invalid.writeAsString('not an image');
      await expectLater(store.importPhoto(invalid.path), throwsArgumentError);
      expect(await store.resolve(relative).exists(), isTrue);
    } finally { await dir.delete(recursive: true); }
  });
  test('disconnected AI reports unavailability instead of producing a ready result', () async {
    await expectLater(ProcessingService().analyze('local-garment'), throwsA(isA<ProcessingUnavailable>()));
  });
}
