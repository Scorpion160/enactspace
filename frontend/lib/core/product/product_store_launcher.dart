import 'package:url_launcher/url_launcher.dart';

import 'product_bootstrap_models.dart';

abstract interface class ProductStoreLauncher {
  Future<bool> launch(Uri uri);
}

class ExternalProductStoreLauncher implements ProductStoreLauncher {
  const ExternalProductStoreLauncher();

  @override
  Future<bool> launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

class ProductStoreUrlValidator {
  const ProductStoreUrlValidator._();

  static Uri? trustedUri(String? value, ProductMobilePlatform platform) {
    if (value == null || value.trim() != value || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.host.isEmpty ||
        uri.port != 443) {
      return null;
    }

    switch (platform) {
      case ProductMobilePlatform.android:
        final query = uri.queryParametersAll;
        if (uri.host.toLowerCase() != 'play.google.com' ||
            (uri.path != '/store/apps/details' &&
                uri.path != '/store/apps/details/') ||
            query['id']?.length != 1 ||
            query['id']!.single != 'sn.enactusesp.enactspace' ||
            !query.keys.every(const {'id', 'hl', 'gl'}.contains)) {
          return null;
        }
        return uri;
      case ProductMobilePlatform.ios:
        final segments = uri.pathSegments
            .where((part) => part.isNotEmpty)
            .toList();
        if (uri.host.toLowerCase() != 'apps.apple.com' ||
            !segments.contains('app') ||
            segments.isEmpty ||
            !RegExp(r'^id\d+$').hasMatch(segments.last)) {
          return null;
        }
        return uri;
    }
  }
}
