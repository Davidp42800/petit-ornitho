import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<({double latitude, double longitude, double? accuracy})>
observationLocation() {
  final result =
      Completer<({double latitude, double longitude, double? accuracy})>();
  if (!web.window.isSecureContext) {
    return Future.error(
      StateError(
        'La position automatique nécessite une connexion HTTPS. Tu peux saisir les coordonnées ci-dessous.',
      ),
    );
  }
  web.window.navigator.geolocation.getCurrentPosition(
    ((web.GeolocationPosition p) {
      if (!result.isCompleted) {
        result.complete((
          latitude: p.coords.latitude,
          longitude: p.coords.longitude,
          accuracy: p.coords.accuracy,
        ));
      }
    }).toJS,
    ((web.GeolocationPositionError e) {
      if (!result.isCompleted) {
        result.completeError(
          StateError(
            e.code == 1
                ? 'Localisation non autorisée. Tu peux saisir le point GPS manuellement.'
                : 'Position indisponible. Réessaie ou saisis les coordonnées manuellement.',
          ),
        );
      }
    }).toJS,
    web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 15000,
      maximumAge: 0,
    ),
  );
  return result.future.timeout(
    const Duration(seconds: 17),
    onTimeout: () => throw StateError(
      'La localisation prend trop de temps. Réessaie ou saisis les coordonnées.',
    ),
  );
}
