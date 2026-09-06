import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  final String version;
  final String buildNumber;

  const AppInfo({required this.version, required this.buildNumber});

  String get display => 'Version $version ($buildNumber)';
}

abstract interface class AppInfoProvider {
  Future<AppInfo> load();
}

class PackageAppInfoProvider implements AppInfoProvider {
  @override
  Future<AppInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(version: info.version, buildNumber: info.buildNumber);
  }
}
