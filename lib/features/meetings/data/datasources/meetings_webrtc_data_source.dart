// meetings_webrtc_data_source.dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MeetingsWebRTCDataSource {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  Future<void> initConnection(Map<String, dynamic> config) async {
    _peerConnection = await createPeerConnection(config);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
    for (var track in _localStream!.getAudioTracks()) {
      _peerConnection?.addTrack(track, _localStream!);
    }
  }

  void setOnRemoteTrack(void Function(RTCTrackEvent event) onTrack) {
    _peerConnection?.onTrack = onTrack;
  }

  Future<void> close() async {
    await _peerConnection?.close();
    await _localStream?.dispose();
  }

  RTCPeerConnection? get peerConnection => _peerConnection;
  MediaStream? get localStream => _localStream;
}