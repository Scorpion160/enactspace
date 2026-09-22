import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:frontend/features/attendance/services/nfc_tag_payload.dart';

NfcTagIdentifierReaders readersFor({
  List<int>? android,
  List<int>? iosMiFare,
  List<int>? iosIso7816,
  List<int>? iosIso15693,
}) {
  return NfcTagIdentifierReaders(
    android: (_) => android,
    iosMiFare: (_) => iosMiFare,
    iosIso7816: (_) => iosIso7816,
    iosIso15693: (_) => iosIso15693,
  );
}

void main() {
  const tag = NfcTag(data: Object());

  test('same identifier bytes always produce the existing Android UID', () {
    expect(normalizeNfcIdentifier([0, 15, 16, 255]), '000f10ff');
    expect(normalizeNfcIdentifier([0, 15, 16, 255]), '000f10ff');
  });

  test('Android identifier remains supported', () {
    expect(
      attendanceNfcTagPayload(tag, readers: readersFor(android: [1, 2, 3])),
      '010203',
    );
  });

  for (final entry in <String, NfcTagIdentifierReaders>{
    'iOS MiFare': readersFor(iosMiFare: [10, 11]),
    'iOS ISO7816': readersFor(iosIso7816: [12, 13]),
    'iOS ISO15693': readersFor(iosIso15693: [14, 15]),
  }.entries) {
    test('${entry.key} identifier is stable and non-empty', () {
      final first = attendanceNfcTagPayload(tag, readers: entry.value);
      final second = attendanceNfcTagPayload(tag, readers: entry.value);
      expect(first, isNotEmpty);
      expect(second, first);
    });
  }

  test(
    'unsupported or empty identifiers are rejected without hash fallback',
    () {
      expect(
        () => attendanceNfcTagPayload(tag, readers: readersFor()),
        throwsA(isA<UnsupportedAttendanceNfcTag>()),
      );
      expect(
        () => normalizeNfcIdentifier([]),
        throwsA(isA<UnsupportedAttendanceNfcTag>()),
      );
    },
  );

  test('polling excludes ISO18092 and keeps ISO14443 plus ISO15693', () {
    expect(supportedAttendanceNfcPollingOptions, {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
    });
    expect(
      supportedAttendanceNfcPollingOptions,
      isNot(contains(NfcPollingOption.iso18092)),
    );
  });
}
