import '../../../core/api/api_client.dart';

String recruitmentMessage(Object error, {required String fallback}) {
  if (error is ApiException) {
    if (error.statusCode == 401) return 'Reconnecte-toi pour poursuivre.';
    if (error.statusCode >= 500) return fallback;
  }
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  final normalized = raw.toLowerCase();
  if (normalized.contains('socket') ||
      normalized.contains('network') ||
      normalized.contains('connection refused') ||
      normalized.contains('timed out')) {
    return 'Vérifie ta connexion et réessaie. Ta saisie est conservée.';
  }
  if (raw.isEmpty ||
      RegExp(
        r'backend|\bapi\b|traceback|sqlalchemy|unsupported operation|typeerror|stateerror|formatexception|https?://|\bjson\b|stack trace',
      ).hasMatch(normalized)) {
    return fallback;
  }
  return raw;
}
