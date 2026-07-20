/// Normalised API error surfaced to blocs/UI. Wraps the backend's error
/// envelope `{ error, message, details? }` and transport failures.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}
