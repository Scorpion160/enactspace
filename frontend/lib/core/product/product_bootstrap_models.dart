enum ProductMobilePlatform {
  android,
  ios;

  String get wireName => name;
}

class ProductClientInfo {
  final ProductMobilePlatform platform;
  final String version;
  final int buildNumber;

  const ProductClientInfo({
    required this.platform,
    required this.version,
    required this.buildNumber,
  });
}

class ProductMaintenanceDecision {
  final bool active;
  final String? message;

  const ProductMaintenanceDecision({required this.active, this.message});
}

class ProductBootstrap {
  final bool configured;
  final ProductMobilePlatform platform;
  final String clientVersion;
  final int clientBuildNumber;
  final String? currentVersion;
  final int? currentBuildNumber;
  final String? minimumSupportedVersion;
  final int? minimumSupportedBuildNumber;
  final bool updateAvailable;
  final bool updateRequired;
  final bool forceUpdate;
  final String? storeUrl;
  final ProductMaintenanceDecision maintenance;

  const ProductBootstrap({
    required this.configured,
    required this.platform,
    required this.clientVersion,
    required this.clientBuildNumber,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.minimumSupportedVersion,
    required this.minimumSupportedBuildNumber,
    required this.updateAvailable,
    required this.updateRequired,
    required this.forceUpdate,
    required this.storeUrl,
    required this.maintenance,
  });

  factory ProductBootstrap.fromJson(
    Map<String, dynamic> json, {
    required ProductClientInfo requested,
  }) {
    final platformName = _requiredString(json, 'platform');
    if (platformName != requested.platform.wireName) {
      throw const FormatException('Unexpected product platform');
    }
    final clientVersion = _requiredString(json, 'client_version');
    final clientBuildNumber = _requiredPositiveInt(json, 'client_build_number');
    if (clientVersion != requested.version ||
        clientBuildNumber != requested.buildNumber) {
      throw const FormatException('Unexpected client metadata');
    }

    final currentVersion = _nullableString(json, 'current_version');
    final currentBuild = _nullablePositiveInt(json, 'current_build_number');
    final minimumVersion = _nullableString(json, 'minimum_supported_version');
    final minimumBuild = _nullablePositiveInt(
      json,
      'minimum_supported_build_number',
    );
    if ((currentVersion == null) != (currentBuild == null) ||
        (minimumVersion == null) != (minimumBuild == null)) {
      throw const FormatException('Incomplete release metadata');
    }

    final configured = _requiredBool(json, 'configured');
    final updateAvailable = _requiredBool(json, 'update_available');
    final updateRequired = _requiredBool(json, 'update_required');
    final forceUpdate = _requiredBool(json, 'force_update');
    if ((updateAvailable && currentBuild == null) ||
        (updateRequired && minimumBuild == null) ||
        (forceUpdate && currentBuild == null)) {
      throw const FormatException('Inconsistent update decision');
    }
    if (!configured &&
        (currentBuild != null ||
            minimumBuild != null ||
            updateAvailable ||
            updateRequired ||
            forceUpdate)) {
      throw const FormatException('Inconsistent unconfigured decision');
    }

    final maintenanceJson = json['maintenance'];
    if (maintenanceJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid maintenance decision');
    }
    final maintenance = ProductMaintenanceDecision(
      active: _requiredBool(maintenanceJson, 'active'),
      message: _nullableString(maintenanceJson, 'message'),
    );

    return ProductBootstrap(
      configured: configured,
      platform: requested.platform,
      clientVersion: clientVersion,
      clientBuildNumber: clientBuildNumber,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuild,
      minimumSupportedVersion: minimumVersion,
      minimumSupportedBuildNumber: minimumBuild,
      updateAvailable: updateAvailable,
      updateRequired: updateRequired,
      forceUpdate: forceUpdate,
      storeUrl: _nullableString(json, 'store_url'),
      maintenance: maintenance,
    );
  }
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key');
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value;
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) throw FormatException('Invalid $key');
  return value;
}

int? _nullablePositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int || value <= 0) throw FormatException('Invalid $key');
  return value;
}
