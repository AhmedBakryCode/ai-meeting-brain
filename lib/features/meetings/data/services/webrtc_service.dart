import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

import '../../../../core/network/signalr_service.dart';

/// Manages real-time peer-to-peer audio between meeting participants via WebRTC.
/// SignalR is used as the signaling channel (offer/answer/ICE exchange).
/// Actual audio travels directly between devices (P2P).
class WebRtcService {
  WebRtcService({required SignalRService signalRService})
    : _signalRService = signalRService;

  final SignalRService _signalRService;
  static const _nativeAudioChannel = MethodChannel('com.example.meeting_brain/audio_manager');

  String? _currentUserId;
  String? _currentMeetingId;

  // One RTCPeerConnection per remote participant
  final Map<String, webrtc.RTCPeerConnection> _peerConnections = {};

  // Audio volume levels (0.0 to 1.0) keyed by user ID (including 'local')
  final Map<String, double> _audioLevels = {};
  final StreamController<Map<String, double>> _audioLevelsController =
      StreamController<Map<String, double>>.broadcast();
  Timer? _statsTimer;
  final Map<String, webrtc.MediaStream> _remoteStreams = {};
  final Map<String, webrtc.RTCVideoRenderer> _audioRenderers =
      {}; // Force audio sink
  final Map<String, List<webrtc.RTCIceCandidate>> _earlyCandidates =
      {}; // Prevent ICE races

  // Local audio stream (microphone)
  webrtc.MediaStream? _localStream;

  Future<void> _drainEarlyCandidates(
    String userId,
    webrtc.RTCPeerConnection pc,
  ) async {
    final earlyCandidates = _earlyCandidates.remove(userId) ?? [];
    if (earlyCandidates.isNotEmpty) {
      print(
        '🧊 [WebRTC] Draining ${earlyCandidates.length} queued ICE candidates for $userId',
      );
      for (final c in earlyCandidates) {
        await pc.addCandidate(c);
      }
    }
  }

  // ICE servers from backend
  List<Map<String, dynamic>> _iceServers = [];

  // ICE servers fallback
  final List<Map<String, dynamic>> _fallbackIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  bool _isInitialized = false;
  bool _speakerEnabled = true;

  Stream<Map<String, double>> get audioLevelsStream => _audioLevelsController.stream;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Call once after joining the SignalR meeting to start audio.
  Future<void> initialize({
    required String userId,
    required String meetingId,
    required List<Map<String, dynamic>> iceServers,
  }) async {
    if (_isInitialized) {
      print('⚠️ [WebRTC] Already initialized, skipping.');
      return;
    }

    _currentUserId = userId;
    _currentMeetingId = meetingId;
    _iceServers = iceServers;

    print('🚀 [WebRTC] Initializing... userId=$userId, meetingId=$meetingId');
    print('🧊 [WebRTC] ICE servers count: ${iceServers.length}');
    for (final s in iceServers) print('   ↳ ${s["urls"]}');

    // Get local microphone stream
    try {
      // Request specific OS microphone and speaker routing using audio_session
      // (mobile only — AudioSession is not available on web)
      if (!kIsWeb) {
        try {
          final session = await AudioSession.instance;
          await session.configure(
            const AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
              avAudioSessionMode: AVAudioSessionMode.videoChat,
              avAudioSessionRouteSharingPolicy:
                  AVAudioSessionRouteSharingPolicy.defaultPolicy,
              avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
              androidAudioAttributes: AndroidAudioAttributes(
                contentType: AndroidAudioContentType.speech,
                flags: AndroidAudioFlags.none,
                usage: AndroidAudioUsage.voiceCommunication,
              ),
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
              androidWillPauseWhenDucked: false,
            ),
          );
          await session.setActive(true);
          print('🎧 [WebRTC] AudioSession hardware parameters applied successfully');
        } catch (e) {
          print('⚠️ [WebRTC] AudioSession config warning: $e');
        }
      }

      _localStream = await webrtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      final tracks = _localStream?.getAudioTracks() ?? [];
      print('🎤 [WebRTC] Local mic tracks: ${tracks.length}');
      if (tracks.isEmpty) {
        print('❌ [WebRTC] CRITICAL: No audio tracks in local stream!');
      }
      for (final t in tracks) {
        print('   ↳ track id=${t.id}, enabled=${t.enabled}');
        // Ensure track is enabled
        t.enabled = true;
      }

      // Force audio output to external speaker — mobile only
      if (!kIsWeb) {
        await webrtc.Helper.setSpeakerphoneOn(true);
        try {
          await _nativeAudioChannel.invokeMethod('setCommunicationMode');
          print('🎧 [WebRTC] Native Audio Communication Mode activated');
        } catch (e) {
          print('⚠️ [WebRTC] Native Audio activation failed: $e');
        }
        print('🔊 [WebRTC] Speakerphone forced ON');
      }
    } catch (e) {
      print('❌ [WebRTC] getUserMedia FAILED: $e');
      rethrow;
    }

    // Register SignalR listeners for signaling
    _registerSignalRListeners();

    // Start stats polling for volume levels
    _startStatsPolling();

    // Diagnostic Heartbeat: Print connection status every 5s
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isInitialized) {
        timer.cancel();
        return;
      }
      if (_peerConnections.isEmpty) {
        print('📡 [DIAGNOSTICS] No active peers yet.');
      }
      for (final entry in _peerConnections.entries.toList()) {
        final userId = entry.key;
        final pc = entry.value;
        pc.getConnectionState().then((state) {
          print('📡 [DIAGNOSTICS] Peer [$userId] Connection State: $state');
        });
      }
    });
    _isInitialized = true;
    print('✅ [WebRTC] Initialization complete.');
  }

  /// Call when a new participant joins — we initiate the offer to them.
  Future<void> callParticipant(String remoteUserId) async {
    print(
      '📞 [WebRTC] callParticipant($remoteUserId) — isInitialized=$_isInitialized, currentUser=$_currentUserId',
    );
    if (!_isInitialized) {
      print('⚠️ [WebRTC] callParticipant skipped: NOT initialized yet!');
      return;
    }
    if (remoteUserId == _currentUserId) {
      print('⚠️ [WebRTC] callParticipant skipped: same userId as self.');
      return;
    }

    // ── Check for stale (non-connected) peer connections ──────────────────
    if (_peerConnections.containsKey(remoteUserId)) {
      final existingPc = _peerConnections[remoteUserId]!;
      final existingState = existingPc.connectionState;
      final isActive =
          existingState == webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
          existingState == webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnecting;

      if (isActive) {
        print(
          '⚠️ [WebRTC] callParticipant skipped: already have ACTIVE connection to $remoteUserId (state=$existingState)',
        );
        return;
      }

      // Stale connection (New/Failed/Disconnected) — tear it down and retry
      print(
        '🔄 [WebRTC] Stale connection to $remoteUserId (state=$existingState). Closing and re-initiating.',
      );
      removeParticipant(remoteUserId);
    }

    final pc = await _createPeerConnection(remoteUserId);
    
    // Process any queued ICE candidates that arrived before PC was ready
    await _drainEarlyCandidates(remoteUserId, pc);

    // Create and send offer - using the exact JSON format the server expects
    final offer = await pc.createOffer({'offerToReceiveAudio': true});
    await pc.setLocalDescription(offer);

    final sdpJson = jsonEncode({'type': offer.type, 'sdp': offer.sdp});
    
    print('📤 [WebRTC] Sending Offer (JSON) to $remoteUserId');
    try {
      await _signalRService.invoke(
        'SendOffer',
        args: [_currentMeetingId ?? '', remoteUserId, sdpJson],
      );
      print('✅ [WebRTC] SendOffer successful');
    } catch (e) {
      print('❌ [WebRTC] SendOffer FAILED: $e');
    }
  }

  /// Call when a participant leaves — close their connection.
  void removeParticipant(String remoteUserId) {
    final pc = _peerConnections.remove(remoteUserId);
    pc?.close();

    final renderer = _audioRenderers.remove(remoteUserId);
    if (renderer != null) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    _remoteStreams.remove(remoteUserId);
    _earlyCandidates.remove(remoteUserId);
  }

  /// Returns true if we have an active (Connected or Connecting) peer connection.
  bool hasActiveConnection(String remoteUserId) {
    final pc = _peerConnections[remoteUserId];
    if (pc == null) return false;
    final state = pc.connectionState;
    return state == webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
        state == webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnecting;
  }

  /// Mute/unmute local microphone.
  void setMicEnabled(bool enabled) {
    final tracks = _localStream?.getAudioTracks() ?? [];
    print(
      '🎤 [WebRTC] setMicEnabled: $enabled, tracks count: ${tracks.length}',
    );
    for (final track in tracks) {
      track.enabled = enabled;
      print('   ↳ Track ${track.id} enabled set to: $enabled');
    }
  }

  /// Enable/disable playback of remote audio (speaker).
  void setSpeakerEnabled(bool enabled) {
    _speakerEnabled = enabled;
    for (final stream in _remoteStreams.values) {
      for (final track in stream.getAudioTracks()) {
        track.enabled = enabled;
      }
    }
  }

  /// Clean up everything — call when leaving the meeting.
  Future<void> dispose() async {
    _signalRService.off('UserJoined');
    _signalRService.off('UserLeft');
    _signalRService.off('ReceiveOffer');
    _signalRService.off('ReceiveAnswer');
    _signalRService.off('ReceiveIceCandidate');

    for (final pc in _peerConnections.values.toList()) {
      await pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    _isInitialized = false;
    _statsTimer?.cancel();
    _statsTimer = null;

    // Reset native audio mode to normal — mobile only
    if (!kIsWeb) {
      try {
        await _nativeAudioChannel.invokeMethod('resetAudioMode');
        print('🎧 [WebRTC] Native Audio Mode reset to NORMAL');
      } catch (e) {
        print('⚠️ [WebRTC] Native Audio reset failed: $e');
      }
    }
  }

  // ─── Internal: Volume Stats ────────────────────────────────────────────────

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      final Map<String, double> currentLevels = {};

      // Local mic level check could be added here if needed via specialized analyzer,
      // but for now let's focus on peer levels from WebRTC stats.
      for (final entry in _peerConnections.entries.toList()) {
        final userId = entry.key;
        final pc = entry.value;

        if (pc.connectionState == webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          final stats = await pc.getStats();
          for (final report in stats) {
            if (report.type == 'inbound-rtp' && report.values['kind'] == 'audio') {
              // audioLevel is 0.0 to 1.0 in most implementations
              final level = double.tryParse(report.values['audioLevel']?.toString() ?? '0') ?? 0.0;
              currentLevels[userId] = level;
            }
          }
        }
      }
      
      _audioLevelsController.add(currentLevels);
    });
  }

  // ─── Internal: SignalR listeners ───────────────────────────────────────────

  void _registerSignalRListeners() {
    print(
      '📡 [WebRTC] Registering SignalR listeners: UserJoined, UserLeft, ReceiveOffer, ReceiveAnswer, ReceiveIceCandidate',
    );

    // ─────────────────────────────────────────────────────────────────────────
    // UserJoined — Triggered when a new user enters the hub
    // ─────────────────────────────────────────────────────────────────────────
    _signalRService.on('UserJoined', (args) async {
      print('👤 [WebRTC] SignalR: UserJoined raw args: $args');
      try {
        if (args == null || args.isEmpty) return;
        
        String userId = '';
        if (args.first is Map) {
          final data = Map<String, dynamic>.from(args.first as Map);
          userId = (data['userId'] ?? data['UserId'] ?? '').toString();
        } else {
          userId = args.first.toString();
        }

        if (userId.isNotEmpty && userId != _currentUserId) {
          print('👤 [WebRTC] User detected in hub: $userId (Waiting for Bloc to decide if we should call)');
        }
      } catch (e) {
        print('❌ [WebRTC] Error in UserJoined handler: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // UserLeft — Triggered when a user disconnects or leaves
    // ─────────────────────────────────────────────────────────────────────────
    _signalRService.on('UserLeft', (args) {
      print('👋 [WebRTC] SignalR: UserLeft raw args: $args');
      try {
        if (args == null || args.isEmpty) return;

        String userId = '';
        if (args.first is Map) {
          final data = Map<String, dynamic>.from(args.first as Map);
          userId = (data['userId'] ?? data['UserId'] ?? '').toString();
        } else {
          userId = args.first.toString();
        }

        if (userId.isNotEmpty) {
          removeParticipant(userId);
        }
      } catch (e) {
        print('❌ [WebRTC] Error in UserLeft handler: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ReceiveOffer
    // ─────────────────────────────────────────────────────────────────────────
    _signalRService.on('ReceiveOffer', (args) async {
      print('📨 [WebRTC] ReceiveOffer raw args: $args');
      try {
        if (args == null || args.isEmpty) return;

        String fromUserId = '';
        String sdpOffer = '';

        if (args.first is Map) {
          final data = Map<String, dynamic>.from(args.first as Map);
          fromUserId = (data['fromUserId'] ?? data['FromUserId'] ?? '').toString();
          sdpOffer = (data['sdpOffer'] ?? data['SdpOffer'] ?? data['sdp'] ?? '').toString();
        } else {
          // Dynamic positional parsing: find a GUID-like string (length 36) for User ID,
          // and a JSON-like string (starts with '{' and contains 'sdp') for SDP
          for (final arg in args) {
            final str = arg?.toString() ?? '';
            if (str.length == 36 && str.contains('-')) {
              // Usually GUID is exactly 36 chars (e.g. 97ab14c9-5612-4199-ad3e-ffc65909f0a5)
              fromUserId = str;
            } else if (str.trim().startsWith('{') && str.contains('sdp')) {
              sdpOffer = str;
            }
          }
          // Fallback if not found: Assume standard SendOffer args: [senderId, meetingId, sdp]
          if (fromUserId.isEmpty && args.length >= 1) {
            fromUserId = args[0]?.toString() ?? '';
          }
          if (sdpOffer.isEmpty && args.length >= 3) {
            sdpOffer = args[2]?.toString() ?? '';
          }
        }

        if (fromUserId.isEmpty || sdpOffer.isEmpty || fromUserId == _currentUserId) {
          print('⚠️ [WebRTC] Invalid ReceiveOffer payload. fromUserId=$fromUserId, sdp=$sdpOffer');
          return;
        }

        // CRITICAL: Unpack JSON
        String actualSdp = sdpOffer;
        String type = 'offer';
        if (sdpOffer.trim().startsWith('{')) {
          try {
            final decoded = jsonDecode(sdpOffer);
            actualSdp = decoded['sdp'] ?? sdpOffer;
            type = decoded['type'] ?? 'offer';
          } catch (_) {}
        }

        print('📥 [WebRTC] ReceiveOffer from=$fromUserId, type=$type');

        if (!_peerConnections.containsKey(fromUserId)) {
          await _createPeerConnection(fromUserId);
        }
        final pc = _peerConnections[fromUserId]!;

        await pc.setRemoteDescription(webrtc.RTCSessionDescription(actualSdp, type));
        print('   ✅ setRemoteDescription($type) done for $fromUserId');

        await _drainEarlyCandidates(fromUserId, pc);

        final answer = await pc.createAnswer({'offerToReceiveAudio': true});
        await pc.setLocalDescription(answer);
        
        final sdpJson = jsonEncode({'type': answer.type, 'sdp': answer.sdp});

        try {
          await _signalRService.invoke('SendAnswer', args: [_currentMeetingId ?? '', fromUserId, sdpJson]);
          print('📤 [WebRTC] Sent Answer (JSON) to $fromUserId ✅');
        } catch (e) {
          print('❌ [WebRTC] SendAnswer FAILED for $fromUserId: $e');
        }
      } catch (e) {
        print('❌ [WebRTC] Error in ReceiveOffer handler: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ReceiveAnswer
    // ─────────────────────────────────────────────────────────────────────────
    _signalRService.on('ReceiveAnswer', (args) async {
      print('📨 [WebRTC] ReceiveAnswer raw args: $args');
      try {
        if (args == null || args.isEmpty) {
          print('⚠️ [WebRTC] ReceiveAnswer: args null or empty!');
          return;
        }

        String fromUserId = '';
        String sdpAnswer = '';

        if (args.first is Map) {
          final data = Map<String, dynamic>.from(args.first as Map);
          fromUserId = (data['fromUserId'] ?? data['FromUserId'] ?? '').toString();
          sdpAnswer = (data['sdpAnswer'] ?? data['SdpAnswer'] ?? data['sdp'] ?? '').toString();
        } else {
          for (final arg in args) {
            final str = arg?.toString() ?? '';
            if (str.length == 36 && str.contains('-')) {
              fromUserId = str;
            } else if (str.trim().startsWith('{') && str.contains('sdp')) {
              sdpAnswer = str;
            }
          }
          if (fromUserId.isEmpty && args.length >= 1) {
            fromUserId = args[0]?.toString() ?? '';
          }
          if (sdpAnswer.isEmpty && args.length >= 3) {
            sdpAnswer = args[2]?.toString() ?? '';
          }
        }

        if (fromUserId.isEmpty || sdpAnswer.isEmpty) return;

        // CRITICAL: Unpack JSON
        String actualSdp = sdpAnswer;
        String type = 'answer';
        if (sdpAnswer.trim().startsWith('{')) {
          try {
            final decoded = jsonDecode(sdpAnswer);
            actualSdp = decoded['sdp'] ?? sdpAnswer;
            type = decoded['type'] ?? 'answer';
          } catch (_) {}
        }

        print('📥 [WebRTC] ReceiveAnswer from=$fromUserId, type=$type');

        final pc = _peerConnections[fromUserId];
        if (pc == null) {
          print('⚠️ [WebRTC] ReceiveAnswer: No peer connection found for $fromUserId! Known peers: ${_peerConnections.keys.toList()}');
        } else {
          await pc.setRemoteDescription(webrtc.RTCSessionDescription(actualSdp, type));
          print('   ✅ setRemoteDescription($type) done for $fromUserId');
          await _drainEarlyCandidates(fromUserId, pc);
          print('✅ [WebRTC] Connection with $fromUserId should now be established.');
        }
      } catch (e) {
        print('❌ [WebRTC] Error in ReceiveAnswer handler: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ReceiveIceCandidate
    // ─────────────────────────────────────────────────────────────────────────
    _signalRService.on('ReceiveIceCandidate', (args) async {
      print('📨 [WebRTC] ReceiveIceCandidate raw args: $args');
      try {
        if (args == null || args.isEmpty) {
          print('⚠️ [WebRTC] ReceiveIceCandidate: args null or empty!');
          return;
        }

        String fromUserId = '';
        dynamic candidateRaw;

        if (args.first is Map) {
          final data = Map<String, dynamic>.from(args.first as Map);
          fromUserId = (data['fromUserId'] ?? data['FromUserId'] ?? '').toString();
          candidateRaw = data['candidate'] ?? data['Candidate'] ?? data;
        } else {
          // Positional: [meetingId, fromUserId, candidateJson]
          // We KNOW the meetingId, so we use it to differentiate the two GUIDs
          final meetingId = _currentMeetingId ?? '';

          for (final arg in args) {
            final str = arg?.toString() ?? '';
            // It's a candidate if it's a JSON object with 'sdp'/'candidate' key
            if (str.trim().startsWith('{') && (str.contains('candidate') || str.contains('sdp'))) {
              candidateRaw = str;
            } else if (str.length == 36 && str.contains('-') && str != meetingId) {
              // It's a GUID but NOT the meetingId — must be fromUserId
              fromUserId = str;
            }
          }

          // Fallback: classic positional order [meetingId, fromUserId, candidateJson]
          if (fromUserId.isEmpty && args.length >= 2) {
            fromUserId = args[1]?.toString() ?? '';
          }
          if (candidateRaw == null && args.length >= 3) {
            candidateRaw = args[2];
          }

          // Decode JSON string candidate
          if (candidateRaw is String && candidateRaw.trim().startsWith('{')) {
            try {
              candidateRaw = jsonDecode(candidateRaw);
            } catch (_) {
              print('⚠️ [WebRTC] Failed to decode ICE candidate string: $candidateRaw');
            }
          }

          // Reconstruct from individual positional args (5-arg format)
          if (args.length >= 5 && candidateRaw is! Map) {
            candidateRaw = {
              'candidate': args[2]?.toString(),
              'sdpMid': args[3]?.toString(),
              'sdpMLineIndex': args[4] is int ? args[4] : int.tryParse(args[4]?.toString() ?? '0') ?? 0,
            };
          }
        }

        if (fromUserId.isEmpty || candidateRaw == null) {
          print('⚠️ [WebRTC] ReceiveIceCandidate: fromUserId empty or candidate null! fromUserId=$fromUserId');
          return;
        }

        print('🧊 [WebRTC] ICE candidate from=$fromUserId, type=${candidateRaw.runtimeType}');

        final pc = _peerConnections[fromUserId];
        if (pc == null) {
          print('⚠️ [WebRTC] Queuing early ICE candidate for $fromUserId as pc is null');
          final candidate = _parseIceCandidate(candidateRaw);
          if (candidate != null) {
            _earlyCandidates.putIfAbsent(fromUserId, () => []).add(candidate);
          }
          return;
        }

        final parsed = _parseIceCandidate(candidateRaw);
        if (parsed != null) {
          await pc.addCandidate(parsed);
          print('   ✅ ICE candidate added for $fromUserId');
        }
      } catch (e) {
        print('❌ [WebRTC] Error in ReceiveIceCandidate handler: $e');
      }
    });
  }

  /// Parse an ICE candidate from various formats.
  webrtc.RTCIceCandidate? _parseIceCandidate(dynamic candidateRaw) {
    if (candidateRaw is String) {
      if (candidateRaw.trim().startsWith('{')) {
        try {
          final parsed = jsonDecode(candidateRaw);
          if (parsed is Map) {
            final sdpMLineIndex = parsed['sdpMLineIndex'];
            return webrtc.RTCIceCandidate(
              parsed['candidate']?.toString() ?? '',
              parsed['sdpMid']?.toString() ?? '0',
              sdpMLineIndex is int
                  ? sdpMLineIndex
                  : int.tryParse(sdpMLineIndex?.toString() ?? '0') ?? 0,
            );
          }
        } catch (_) {}
      }
      
      // Fallback for simple string candidates (default to audio channel 0)
      return webrtc.RTCIceCandidate(
        candidateRaw.toString(),
        '0', // Default mid for audio
        0,   // Default index for audio
      );
    } else if (candidateRaw is Map) {
      final sdpMLineIndex = candidateRaw['sdpMLineIndex'];
      return webrtc.RTCIceCandidate(
        candidateRaw['candidate']?.toString() ?? '',
        candidateRaw['sdpMid']?.toString(),
        sdpMLineIndex is int
            ? sdpMLineIndex
            : int.tryParse(sdpMLineIndex?.toString() ?? ''),
      );
    }
    return null;
  }

  // ─── Internal: peer connection factory ─────────────────────────────────────

  Future<webrtc.RTCPeerConnection> _createPeerConnection(
    String remoteUserId,
  ) async {
    // 🧊 Merge backend-provided ICE servers with Google STUN fallbacks
    final List<Map<String, dynamic>> combinedIceServers = [
      ..._iceServers,
      ..._fallbackIceServers,
    ];

    print('🔧 [WebRTC] Creating peer connection for $remoteUserId');
    print('   🧊 Final ICE Config (Combined): $combinedIceServers');

    final configuration = {
      'iceServers': combinedIceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'iceTransportPolicy': 'all',
    };

    final pc = await webrtc.createPeerConnection(configuration);
    _peerConnections[remoteUserId] = pc;

    // ── Add local audio tracks ───────────────────────────────────────────
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        await pc.addTrack(track, _localStream!);
      }
      print('   🎤 Local audio tracks attached to PC for $remoteUserId');
    }

    // ── Handle remote audio tracks (CRITICAL) ─────────────────────────────
    pc.onTrack = (webrtc.RTCTrackEvent event) {
      print('🔊 [WebRTC] Received remote track from $remoteUserId (${event.track.kind})');
      if (event.streams.isNotEmpty) {
        final remoteStream = event.streams.first;
        _remoteStreams[remoteUserId] = remoteStream;
        event.track.enabled = true;

        for (final track in remoteStream.getAudioTracks()) {
          track.enabled = _speakerEnabled;
        }

        // RTCVideoRenderer is used purely as an audio sink on mobile.
        // On web, the browser handles audio playback natively — no renderer needed.
        if (!kIsWeb) {
          if (!_audioRenderers.containsKey(remoteUserId)) {
            final renderer = webrtc.RTCVideoRenderer();
            renderer.initialize().then((_) {
              renderer.srcObject = remoteStream;
              _audioRenderers[remoteUserId] = renderer;
              webrtc.Helper.setSpeakerphoneOn(true);
              print('🔊 [WebRTC] Bound audio renderer for $remoteUserId');
            });
          } else {
            final renderer = _audioRenderers[remoteUserId];
            if (renderer != null) {
              renderer.srcObject = remoteStream;
              webrtc.Helper.setSpeakerphoneOn(true);
            }
          }
        }
      }
    };

    // ── Monitor Status Changes (Extremely Verbose) ────────────────────────
    pc.onIceConnectionState = (state) {
      print('🧊 [WebRTC] ICE Connection [$remoteUserId]: ${state.toString().split('.').last}');
      if (state == webrtc.RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == webrtc.RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        print('✅ [WebRTC] P2P Audio tunnel established with $remoteUserId!');
        if (!kIsWeb) {
          Future.delayed(const Duration(milliseconds: 500), () {
            webrtc.Helper.setSpeakerphoneOn(true);
          });
        }
      } else if (state == webrtc.RTCIceConnectionState.RTCIceConnectionStateFailed) {
        print('🚨 [WebRTC] ICE FAILED for $remoteUserId. Potential NAT/Firewall issue. Restarting ICE...');
        pc.restartIce();
      }
    };

    pc.onConnectionState = (state) {
      print('🔗 [WebRTC] Peer Connection [$remoteUserId]: ${state.toString().split('.').last}');
    };

    pc.onSignalingState = (state) {
      print('📡 [WebRTC] Signaling State [$remoteUserId]: ${state.toString().split('.').last}');
    };

    // ── Send ICE candidates as they are discovered ────────────────────────
    pc.onIceCandidate = (candidate) async {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        print('🧊 [WebRTC] ICE gathering complete for $remoteUserId');
        return;
      }
      
      print('🧊 [WebRTC] Generated candidate for $remoteUserId: ${candidate.candidate?.substring(0, 30)}...');
      try {
        final candidateJson = jsonEncode({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });

        await _signalRService.invoke(
          'SendIceCandidate',
          args: [_currentMeetingId ?? '', remoteUserId, candidateJson],
        );
      } catch (e) {
        print('❌ [WebRTC] Failed to send candidate to $remoteUserId: $e');
      }
    };

    return pc;
  }
}
