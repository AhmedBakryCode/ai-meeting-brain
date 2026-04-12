import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';
import '../../../../core/network/signalr_service.dart';

abstract class TranscriptStreamService {
  Future<void> connect(String url, {required String meetingId, String? accessToken});
  Stream<String> get transcriptStream;
  Future<void> sendTranscriptChunk({
    required String meetingId,
    required String text,
    String speakerName = 'User',
    double startTime = 0.0,
    double endTime = 0.0,
  });
  Future<void> disconnect(String meetingId);
}

class TranscriptStreamServiceImpl implements TranscriptStreamService {
  TranscriptStreamServiceImpl({required SignalRService signalRService})
      : _signalRService = signalRService;

  final SignalRService _signalRService;
  final StreamController<String> _controller = StreamController<String>.broadcast();

  @override
  Stream<String> get transcriptStream => _controller.stream;

  @override
  Future<void> connect(String url, {required String meetingId, String? accessToken}) async {
    try {
      // Pass token ONLY via accessTokenFactory — do NOT append to URL manually
      await _signalRService.connect(url, accessToken: accessToken);

      // Register listeners BEFORE invoking JoinMeeting
      _signalRService.on('ReceiveLiveTranscript', (args) {
        if (args != null && args.isNotEmpty && args[0] is Map<String, dynamic>) {
          final data = args[0] as Map<String, dynamic>;
          final text = data['text'] as String?;
          if (text != null && text.isNotEmpty) {
            _controller.add(text);
          }
        }
      });

      _signalRService.on('ParticipantJoined', (args) {
        // Optional: emit a status message or log
      });

      _signalRService.on('ParticipantLeft', (args) {
        // Optional: emit a status message or log
      });

      // Join the meeting room
      await _signalRService.invoke('JoinMeeting', args: [meetingId]);
    } catch (e) {
      throw Exception('SignalR connection failed: $e');
    }
  }

  @override
  Future<void> sendTranscriptChunk({
    required String meetingId,
    required String text,
    String speakerName = 'User',
    double startTime = 0.0,
    double endTime = 0.0,
  }) async {
    try {
      await _signalRService.invoke('SendLiveTranscriptChunk', args: [
        {
          'meetingId': meetingId,
          'speakerName': speakerName,
          'text': text,
          'startTime': startTime,
          'endTime': endTime,
        }
      ]);
    } catch (e) {
      throw Exception('Failed to send live transcript chunk: $e');
    }
  }

  @override
  Future<void> disconnect(String meetingId) async {
    try {
      if (_signalRService.state == HubConnectionState.Connected) {
        await _signalRService.invoke('LeaveMeeting', args: [meetingId]);
      }
      await _signalRService.disconnect();
    } catch (_) {}
  }
}
