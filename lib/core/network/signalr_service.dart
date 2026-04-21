import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  SignalRService();

  HubConnection? _hubConnection;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, List<Function(List<Object?>?)>> _handlers = {};

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  HubConnectionState get state => _hubConnection?.state ?? HubConnectionState.Disconnected;

  Future<void> connect(String url, {String? accessToken, Future<String> Function()? accessTokenFactory}) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      return;
    }

    final httpOptions = HttpConnectionOptions(
      accessTokenFactory: accessTokenFactory ?? (accessToken != null ? () async => accessToken : null),
    );

    _hubConnection = HubConnectionBuilder()
        .withUrl(url, options: httpOptions)
        .withAutomaticReconnect()
        .build();

    // Re-apply any cached event handlers using multiplexing
    _handlers.forEach((method, callbacks) {
      _hubConnection?.on(method, (args) {
        final handlersToCall = List<Function(List<Object?>?)>.from(callbacks);
        for (var handler in handlersToCall) {
          try {
            handler(args);
          } catch (e) {
            print('❌ Error in cached SignalR handler for $method: $e');
          }
        }
      });
    });

    _hubConnection?.onreconnecting(({error}) {
      print('⚠️ SignalR Hub is reconnecting due to error: $error');
    });

    _hubConnection?.onreconnected(({connectionId}) {
      print('✅ SignalR Hub reconnected. New connectionId: $connectionId');
    });

    _hubConnection?.onclose(({error}) {
      print('🚨 SignalR Hub connection closed: $error');
    });

    try {
      await _hubConnection?.start();
      print('✅ SignalR Hub connected');
    } catch (e) {
      print('❌ SignalR Hub connection failed: $e');
      if (e.toString().contains('Cleartext HTTP traffic not permitted')) {
        print('💡 TIP: Add android:usesCleartextTraffic="true" to AndroidManifest.xml');
      }
      rethrow;
    }
  }

  void on(String methodName, Function(List<Object?>?) callback) {
    // For services like NotificationHubService that might reconnect/re-register,
    // we want to ensure we don't accumulate multiple identical handlers.
    // In this app's context, usually one handler per method is enough for notifications.
    final list = _handlers.putIfAbsent(methodName, () => []);
    if (!list.contains(callback)) {
      list.add(callback);
    }
    
    // If the hub is already connected, ensure we have EXACTLY ONE listener
    // that redirects to all our local handlers.
    _hubConnection?.off(methodName);
    _hubConnection?.on(methodName, (args) {
      final handlersToCall = List<Function(List<Object?>?)>.from(_handlers[methodName] ?? []);
      for (var handler in handlersToCall) {
        try {
          handler(args);
        } catch (e) {
          print('❌ Error in SignalR handler for $methodName: $e');
        }
      }
    });
  }

  void off(String methodName) {
    _handlers.remove(methodName);
    _hubConnection?.off(methodName);
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
