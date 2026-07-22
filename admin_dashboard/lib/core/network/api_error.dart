import 'package:dio/dio.dart';

/// Turns a caught error (almost always a DioException) into a message
/// fit to show a user. The backend already returns human-readable
/// French text in `detail` for the errors that matter (e.g. "Cet email
/// est déjà utilisé.") - this just knows how to find that string, plus
/// the two other shapes FastAPI can send: a list of Pydantic field
/// errors (422) and a bare connection failure with no response at all.
String extractApiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];

      if (detail is String) {
        return detail;
      }

      if (detail is List) {
        final messages = detail
            .map((entry) => entry is Map ? entry['msg']?.toString() : entry.toString())
            .whereType<String>()
            .where((message) => message.isNotEmpty);

        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
    }
  }

  return 'Une erreur est survenue. Veuillez réessayer.';
}
