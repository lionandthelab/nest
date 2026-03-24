import 'pwa_install_helper_stub.dart'
    if (dart.library.html) 'pwa_install_helper_web.dart';

abstract class PwaInstallHelper {
  bool get isInstallable;
  bool get isRunningAsPwa;
  bool get isIos;

  Future<bool> promptInstall();
}

PwaInstallHelper createPwaInstallHelper() => createHelper();
