import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';

/// UI messages never expose exception text, URLs, SQL or server diagnostics.
String alumniErrorMessage(
  Object error, {
  String fallback =
      'Impossible de charger les alumni pour le moment. Réessayez dans quelques instants.',
}) {
  if (error is TimeoutException || error is http.ClientException) {
    return 'La connexion avec EnactSpace a été interrompue. Vérifiez votre connexion puis réessayez.';
  }
  if (error is ApiException) {
    switch (error.statusCode) {
      case 401:
        return 'Votre session a expiré. Reconnectez-vous pour continuer.';
      case 403:
        return 'Vous ne disposez pas des droits nécessaires pour cette action.';
      case 404:
        return 'Ce profil ou ce mentorat n’est plus disponible. Actualisez la page.';
      case 400:
      case 409:
      case 422:
        return 'Vérifiez les informations saisies puis réessayez. Si le problème persiste, actualisez la page.';
    }
  }
  return fallback;
}
