class Failure {
  const Failure({required this.message, this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() {
    final codeText = code == null ? '' : '[$code] ';
    return '${codeText}Failure: $message';
  }
}
