import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class LocalAssetStore {
  LocalAssetStore(this.root);
  final Directory root;

  File resolve(String relative) {
    final absolute = p.normalize(p.join(root.path, relative));
    if (!p.isWithin(root.path, absolute)) {
      throw ArgumentError('مسیر تصویر نامعتبر است');
    }
    return File(absolute);
  }

  Future<String> importPhoto(String sourcePath) async {
    final source = File(sourcePath);
    if (await source.length() > 15 * 1024 * 1024) {
      throw ArgumentError('حجم عکس باید کمتر از ۱۵ مگابایت باشد');
    }
    final relative = p.join('garments', '${const Uuid().v4()}.png');
    final target = resolve(relative);
    await target.parent.create(recursive: true);
    final destination = target.path;
    await Isolate.run(() async {
      final bytes = await File(sourcePath).readAsBytes();
      final decoder = img.findDecoderForData(bytes);
      final header = decoder?.startDecode(bytes);
      if (header == null ||
          header.width > 6000 ||
          header.height > 6000 ||
          header.width < 64 ||
          header.height < 64) {
        throw ArgumentError('عکس معتبر با ابعاد ۶۴ تا ۶۰۰۰ پیکسل انتخاب کنید');
      }
      final decoded = decoder!.decodeFrame(0);
      if (decoded == null) throw ArgumentError('خواندن عکس ممکن نشد');
      final oriented = img.bakeOrientation(decoded);
      final bounded = oriented.width > 1600 || oriented.height > 1600
          ? img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? 1600 : null,
              height: oriented.height > oriented.width ? 1600 : null,
            )
          : oriented;
      // Copy RGBA pixels to strip EXIF (including location) without losing alpha.
      final rgba = bounded.convert(format: img.Format.uint8, numChannels: 4);
      final clean = img.Image(
        width: rgba.width,
        height: rgba.height,
        numChannels: 4,
      );
      for (final pixel in rgba) {
        clean.setPixelRgba(
          pixel.x,
          pixel.y,
          pixel.r,
          pixel.g,
          pixel.b,
          pixel.a,
        );
      }
      final temp = File('$destination.tmp');
      try {
        await temp.writeAsBytes(img.encodePng(clean), flush: true);
        await temp.rename(destination);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    });
    return relative;
  }
}
