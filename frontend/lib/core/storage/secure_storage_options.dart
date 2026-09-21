import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const enactSpaceDeviceBoundIosOptions = IOSOptions(
  accessibility: KeychainAccessibility.unlocked_this_device,
);

const enactSpaceSecureStorage = FlutterSecureStorage(
  iOptions: enactSpaceDeviceBoundIosOptions,
);
