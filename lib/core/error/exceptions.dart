class ServerException implements Exception {
  const ServerException([this.message = 'Server error']);
  final String message;
  
  @override
  String toString() => message;
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'Network error']);
  final String message;
  
  @override
  String toString() => message;
}
