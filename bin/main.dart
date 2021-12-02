import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:image/image.dart';

Future<void> main(List<String> arguments) async {
  final directory = Directory.current;
  final pubspecFile = File('${directory.path}/pubspec.yaml');

  final yamlDocument = loadYaml(await pubspecFile.readAsString());

  final iconPath = yamlDocument['icons']['path'];
  final iconFile = File(iconPath);
  final iconDecoded = decodeImage(await iconFile.readAsBytes());

  final iconBackground = yamlDocument['icons']['background'];
  final iconBackgroundFile = File(iconBackground);
  final iconBackgroundDecoded = decodeImage(await iconBackgroundFile.readAsBytes());

  final iconForeground = yamlDocument['icons']['foreground'];
  final iconForegroundFile = File(iconForeground);
  final iconForegroundDecoded = decodeImage(await iconForegroundFile.readAsBytes());

  final iOSDirectory = Directory('${directory.path}/ios');
  final macOSDirectory = Directory('${directory.path}/macos');
  final androidDirectory = Directory('${directory.path}/android');
  final windowsDirectory = Directory('${directory.path}/windows');

  final iconForegroundRescaled = copyResize(iconForegroundDecoded!, width: (iconForegroundDecoded.width * 1.75).toInt(), height: (iconForegroundDecoded.height * 1.75).toInt());
  final iconCropped = copyCrop(iconForegroundRescaled, iconForegroundRescaled.width ~/ 4, iconForegroundRescaled.height ~/ 4, iconForegroundRescaled.width ~/ 2, iconForegroundRescaled.height ~/ 2);
  final iconCombined = copyOnto(decodeImage(await iconBackgroundFile.readAsBytes())!, iconCropped, blend: true, center: true);

  try {
    print('\nGenerating Windows icon...');
    if (await windowsDirectory.exists()) {
      final resized = copyResize(iconCropped, width: 256, interpolation: Interpolation.average);
      final file = await File('${windowsDirectory.path}/runner/resources/app_icon.ico').writeAsBytes(encodeIco(resized));
      print('\tWrote Windows icon to ${file.path}');
    }
  } catch (e) {
    print('\tCouldn\'t generate icon for Windows: $e');
  }

  try {
    print('\nGenerating iOS icons...');
    if (await iOSDirectory.exists()) {
      final files = await Directory('${iOSDirectory.path}/Runner/Assets.xcassets/AppIcon.appiconset').list().toList();
      for (var iconFile in files.where((file) => file.path.endsWith('.png'))) {
        final data = iconFile.uri.pathSegments.last.replaceAll('Icon-App-', '').replaceAll('.png', '');
        final splitData = data.split('@');

        final resolution = double.parse(splitData.first.split('x').first);
        final scale = double.parse(splitData.last[0]);
        final resultResolution = resolution * scale;

        final resized = copyResize(iconCombined, width: resultResolution.toInt(), interpolation: Interpolation.average);
        final file = await File(iconFile.path).writeAsBytes(encodePng(resized));
        print('\tWrote iOS icon to ${file.path}');
      }
    }
  } catch (e) {
    print('\tCouldn\'t generate icons for iOS: $e');
  }

  try {
    print('\nGenerating macOS icons...');
    if (await macOSDirectory.exists()) {
      final files = await Directory('${macOSDirectory.path}/Runner/Assets.xcassets/AppIcon.appiconset').list().toList();
      for (var iconFile in files.where((file) => file.path.endsWith('.png'))) {
        final resolution = int.parse(iconFile.uri.pathSegments.last.replaceAll('app_icon_', '').replaceAll('.png', ''));

        final resized = copyResize(iconCropped, width: resolution.toInt(), interpolation: Interpolation.average);
        final file = await File(iconFile.path).writeAsBytes(encodePng(resized));
        print('\tWrote macOS icon to ${file.path}');
      }
    }
  } catch (e) {
    print('\tCouldn\'t generate icons for macOS: $e');
  }

  try {
    print('\nGenerating Android icons...');
    if (await androidDirectory.exists()) {
      final defaultIcons = [
        'app/src/main/res/mipmap-hdpi/ic_launcher.png',
        'app/src/main/res/mipmap-mdpi/ic_launcher.png',
        'app/src/main/res/mipmap-xhdpi/ic_launcher.png',
        'app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
        'app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      ].map((path) => File('${androidDirectory.path}/$path')).toList();

      final toCreateIcons = {
        'app/src/main/res/drawable-hdpi': 162,
        'app/src/main/res/drawable-mdpi': 108,
        'app/src/main/res/drawable-xhdpi': 216,
        'app/src/main/res/drawable-xxhdpi': 324,
        'app/src/main/res/drawable-xxxhdpi': 432,
      };

      for (var defaultIcon in defaultIcons) {
        final defaultIconDecoded = decodeImage(await defaultIcon.readAsBytes());
        await defaultIcon.writeAsBytes(encodePng(copyResize(iconCombined, width: defaultIconDecoded!.width, interpolation: Interpolation.average)));
        print('\tWrote Android icon to ${defaultIcon.path}');
      }

      for (var toCreateIcon in toCreateIcons.entries) {
        final directory = await Directory('${androidDirectory.path}/${toCreateIcon.key}').create(recursive: true);
        final foregroundFile = await File('${directory.path}/ic_launcher_foreground.png').writeAsBytes(encodePng(copyResize(iconForegroundDecoded, width: toCreateIcon.value, interpolation: Interpolation.average)));
        final backgroundFile = await File('${directory.path}/ic_launcher_background.png').writeAsBytes(encodePng(copyResize(iconBackgroundDecoded!, width: toCreateIcon.value, interpolation: Interpolation.average)));
        print('\tWrote Android icon to ${foregroundFile.path}');
        print('\tWrote Android icon to ${backgroundFile.path}');
      }

      final directory = await Directory('${androidDirectory.path}/app/src/main/res/mipmap-anydpi-v26').create(recursive: true);
      final configFile = await File('${directory.path}/ic_launcher.xml').writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
      ''');
      print('\tWrote Android config to ${configFile.path}');
    }
  } catch (e) {
    print('\tCouldn\'t generate icons for Android: $e');
  }
}

/*
magick convert -resize x72 ./assets/logo.png  ./android/app/src/main/res/mipmap-hdpi/ic_launcher.png
magick convert -resize x48 ./assets/logo.png  ./android/app/src/main/res/mipmap-mdpi/ic_launcher.png
magick convert -resize x96 ./assets/logo.png  ./android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
magick convert -resize x144 ./assets/logo.png ./android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
magick convert -resize x192 ./assets/logo.png ./android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
*/

int lerp(dynamic a, dynamic b, double t) {
  return (a + t * (b - a)).toInt();
}

int lerpColor(int a, int b) {
  double t = getAlpha(b) / 255.0;
  return getColor(lerp(getRed(a), getRed(b), t), lerp(getGreen(a), getGreen(b), t), lerp(getBlue(a), getBlue(b), t));
}

Image copyOnto(
  Image dst,
  Image src, {
  int? dstX,
  int? dstY,
  int? srcX,
  int? srcY,
  int? srcW,
  int? srcH,
  bool blend = true,
  bool center = false,
}) {
  dstX ??= 0;
  dstY ??= 0;
  srcX ??= 0;
  srcY ??= 0;
  srcW ??= src.width;
  srcH ??= src.height;

  if (center) {
    {
      // if [src] is wider than [dst]
      var wdt = (dst.width - src.width);
      if (wdt < 0) wdt = 0;
      dstX = wdt ~/ 2;
    }
    {
      // if [src] is higher than [dst]
      var hight = (dst.height - src.height);
      if (hight < 0) hight = 0;
      dstY = hight ~/ 2;
    }
  }

  for (var y = 0; y < srcH; ++y) {
    for (var x = 0; x < srcW; ++x) {
      dst.setPixel(dstX + x, dstY + y, lerpColor(dst.getPixel(dstX + x, dstY + y), src.getPixel(srcX + x, srcY + y)));
    }
  }

  return dst;
}
