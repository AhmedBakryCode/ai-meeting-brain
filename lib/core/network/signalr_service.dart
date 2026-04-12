import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  SignalRService();

  HubConnection? _hubConnection;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  HubConnectionState get state => _hubConnection?.state ?? HubConnectionState.Disconnected;

  Future<void> connect(String url, {String? accessToken}) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      return;
    }

    final httpOptions = HttpConnectionOptions(
      accessTokenFactory: accessToken != null ? () async => accessToken : null,
    );

    _hubConnection = HubConnectionBuilder()
        .withUrl(url, options: httpOptions)
        .build();

    _hubConnection?.onclose(({error}) {
      // Handle close
    });

    try {
      await _hubConnection?.start();
    } catch (e) {
      rethrow;
    }
  }

  void on(String methodName, void Function(List<Object?>?) callback) {
    _hubConnection?.on(methodName, callback);
  }

  Future<Object?> invoke(String methodName, {List<Object>? args}) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      throw Exception('SignalR is not connected');
    }
    return await _hubConnection?.invoke(methodName, args: args);
  }

  Future<void> send(String methodName, {List<Object>? args}) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      throw Exception('SignalR is not connected');
    }
    await _hubConnection?.send(methodName, args: args);
  }

  Future<void> disconnect() async {
    await _hubConnection?.stop();
    _hubConnection = null;
  }
}
