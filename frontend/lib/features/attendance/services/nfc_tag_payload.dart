import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

const supportedAttendanceNfcPollingOptions = <NfcPollingOption>{
  NfcPollingOption.iso14443,
  NfcPollingOption.iso15693,
};

typedef NfcIdentifierReader = List<int>? Function(NfcTag tag);

class NfcTagIdentifierReaders {
  final NfcIdentifierReader android;
  final NfcIdentifierReader iosMiFare;
  final NfcIdentifierReader iosIso7816;
  final NfcIdentifierReader iosIso15693;

  const NfcTagIdentifierReaders({
    required this.android,
    required this.iosMiFare,
    required this.iosIso7816,
    required this.iosIso15693,
  });

  static final platform = NfcTagIdentifierReaders(
    android: (tag) => NfcTagAndroid.from(tag)?.id,
    iosMiFare: (tag) => MiFareIos.from(tag)?.identifier,
    iosIso7816: (tag) => Iso7816Ios.from(tag)?.identifier,
    iosIso15693: (tag) => Iso15693Ios.from(tag)?.identifier,
  );
}

class UnsupportedAttendanceNfcTag implements Exception {
  const UnsupportedAttendanceNfcTag();

  @override
  String toString() => 'Badge NFC non compatible ou impossible à identifier.';
}

String normalizeNfcIdentifier(List<int> identifier) {
  if (identifier.isEmpty) throw const UnsupportedAttendanceNfcTag();
  return identifier
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

String attendanceNfcTagPayload(NfcTag tag, {NfcTagIdentifierReaders? readers}) {
  final activeReaders = readers ?? NfcTagIdentifierReaders.platform;
  for (final readIdentifier in [
    activeReaders.android,
    activeReaders.iosMiFare,
    activeReaders.iosIso7816,
    activeReaders.iosIso15693,
  ]) {
    final identifier = readIdentifier(tag);
    if (identifier != null && identifier.isNotEmpty) {
      return normalizeNfcIdentifier(identifier);
    }
  }
  throw const UnsupportedAttendanceNfcTag();
}
