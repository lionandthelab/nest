import 'dart:io';
import 'package:image/image.dart' as img;

img.Image resizeFit(img.Image src, int maxWidth, int maxHeight) {
  final aspect = src.width / src.height;
  int w, h;
  if (maxWidth / maxHeight > aspect) {
    h = maxHeight;
    w = (maxHeight * aspect).round();
  } else {
    w = maxWidth;
    h = (maxWidth / aspect).round();
  }
  return img.copyResize(src, width: w, height: h, interpolation: img.Interpolation.cubic);
}

void compositeCenter(img.Image base, img.Image overlay, int centerX, int centerY, int maxW, int maxH) {
  final resized = resizeFit(overlay, maxW, maxH);
  final dstX = centerX - (resized.width ~/ 2);
  final dstY = centerY - (resized.height ~/ 2);
  img.compositeImage(base, resized, dstX: dstX, dstY: dstY);
}

void main() {
  final logo3d = img.decodePng(File('assets/logo_3d_mark.png').readAsBytesSync())!;
  final appIcon3d = img.decodePng(File('assets/logo_3d_app_icon.png').readAsBytesSync())!;

  final announcement3d = img.decodePng(File('assets/3d/announcement_3d.png').readAsBytesSync())!;
  final calendar3d = img.decodePng(File('assets/3d/calendar_3d.png').readAsBytesSync())!;
  final books3d = img.decodePng(File('assets/3d/study_books_3d.png').readAsBytesSync())!;
  final bulb3d = img.decodePng(File('assets/3d/tips_lightbulb_3d.png').readAsBytesSync())!;
  final nest3d = img.decodePng(File('assets/3d/empty_nest_3d.png').readAsBytesSync())!;
  final star3d = img.decodePng(File('assets/3d/achievement_star_3d.png').readAsBytesSync())!;

  // 1. Splash Screen
  final splashFile = File('shots/shot_splash_first_screen.png');
  if (splashFile.existsSync()) {
    final splash = img.decodePng(splashFile.readAsBytesSync())!;
    compositeCenter(splash, logo3d, 420, 662, 175, 175);
    splashFile.writeAsBytesSync(img.encodePng(splash));
    print('Updated shots/shot_splash_first_screen.png');
  }

  // 2. Login Screen
  final loginFile = File('shots/shot_login_screen.png');
  if (loginFile.existsSync()) {
    final login = img.decodePng(loginFile.readAsBytesSync())!;
    compositeCenter(login, logo3d, 420, 285, 155, 155);
    loginFile.writeAsBytesSync(img.encodePng(login));
    print('Updated shots/shot_login_screen.png');
  }

  // 3. Signup Screen
  final signupFile = File('shots/shot_signup_screen.png');
  if (signupFile.existsSync()) {
    final signup = img.decodePng(signupFile.readAsBytesSync())!;
    compositeCenter(signup, logo3d, 420, 285, 155, 155);
    signupFile.writeAsBytesSync(img.encodePng(signup));
    print('Updated shots/shot_signup_screen.png');
  }

  // 4. Branding Showcase
  final brandingFile = File('shots/shot_branding_showcase.png');
  if (brandingFile.existsSync()) {
    final branding = img.decodePng(brandingFile.readAsBytesSync())!;
    compositeCenter(branding, logo3d, 310, 375, 195, 195);
    compositeCenter(branding, appIcon3d, 570, 375, 215, 215);
    brandingFile.writeAsBytesSync(img.encodePng(branding));
    print('Updated shots/shot_branding_showcase.png');
  }

  // 5. 3D Assets Showcase
  final assetsShowcaseFile = File('shots/shot_3d_assets_showcase.png');
  if (assetsShowcaseFile.existsSync()) {
    final assets = img.decodePng(assetsShowcaseFile.readAsBytesSync())!;
    const col1X = 245;
    const col2X = 635;
    const row1Y = 320;
    const row2Y = 640;
    const row3Y = 960;
    const iconSize = 130;

    compositeCenter(assets, announcement3d, col1X, row1Y, iconSize, iconSize);
    compositeCenter(assets, calendar3d, col2X, row1Y, iconSize, iconSize);
    compositeCenter(assets, books3d, col1X, row2Y, iconSize, iconSize);
    compositeCenter(assets, bulb3d, col2X, row2Y, iconSize, iconSize);
    compositeCenter(assets, nest3d, col1X, row3Y, iconSize, iconSize);
    compositeCenter(assets, star3d, col2X, row3Y, iconSize, iconSize);

    assetsShowcaseFile.writeAsBytesSync(img.encodePng(assets));
    print('Updated shots/shot_3d_assets_showcase.png');
  }
}
