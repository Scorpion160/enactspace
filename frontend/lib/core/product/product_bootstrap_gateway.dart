import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import 'product_bootstrap_models.dart';

abstract interface class ProductBootstrapGateway {
  Future<ProductBootstrap> fetch();
}

abstract interface class ProductClientInfoProvider {
  Future<ProductClientInfo> load();
}

class ProductReadinessPlatform {
  const ProductReadinessPlatform._();

  static bool applies({required bool isWeb, required TargetPlatform platform}) {
    if (isWeb) return false;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  static bool get appliesToCurrentTarget =>
      applies(isWeb: kIsWeb, platform: defaultTargetPlatform);
}

class PlatformProductClientInfoProvider implements ProductClientInfoProvider {
  const PlatformProductClientInfoProvider();

  @override
  Future<ProductClientInfo> load() async {
    if (!ProductReadinessPlatform.appliesToCurrentTarget) {
      throw UnsupportedError(
        'Product readiness is supported only on Android and iOS.',
      );
    }
    final platform = switch ((kIsWeb, defaultTargetPlatform)) {
      (false, TargetPlatform.android) => ProductMobilePlatform.android,
      (false, TargetPlatform.iOS) => ProductMobilePlatform.ios,
      _ => throw StateError('Unsupported mobile platform'),
    };
    final package = await PackageInfo.fromPlatform();
    final buildNumber = int.tryParse(package.buildNumber);
    if (package.version.trim().isEmpty ||
        buildNumber == null ||
        buildNumber <= 0) {
      throw const FormatException('Invalid application metadata');
    }
    return ProductClientInfo(
      platform: platform,
      version: package.version,
      buildNumber: buildNumber,
    );
  }
}

class ApiProductBootstrapGateway implements ProductBootstrapGateway {
  final ApiClient _api;
  final ProductClientInfoProvider clientInfo;

  ApiProductBootstrapGateway({
    ApiClient? apiClient,
    this.clientInfo = const PlatformProductClientInfoProvider(),
  }) : _api = apiClient ?? ApiClient();

  @override
  Future<ProductBootstrap> fetch() async {
    final requested = await clientInfo.load();
    final query = Uri(
      path: '/product/bootstrap',
      queryParameters: {
        'platform': requested.platform.wireName,
        'version': requested.version,
        'build_number': requested.buildNumber.toString(),
      },
    );
    final response = await _api.get(query.toString(), token: null);
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid product bootstrap response');
    }
    return ProductBootstrap.fromJson(response, requested: requested);
  }
}
