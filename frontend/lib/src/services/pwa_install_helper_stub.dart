import 'pwa_install_helper.dart';

PwaInstallHelper createHelper() => const _PwaInstallHelperStub();

class _PwaInstallHelperStub implements PwaInstallHelper {
  const _PwaInstallHelperStub();

  @override
  bool get isInstallable => false;

  @override
  bool get isRunningAsPwa => false;

  @override
  bool get isIos => false;

  @override
  Future<bool> promptInstall() async => false;
}
