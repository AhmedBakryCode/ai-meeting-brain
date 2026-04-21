import 'dart:async';

import 'package:meeting_brain/core/network/signalr_service.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../../auth/data/models/user_model.dart';

abstract class TranscriptStreamService {
  Future<void> connect(
    String url, {
    required String meetingId,
    List<dynamic>? initialRawParticipants,
  });
  Stream<String> get transcriptStream;
  Stream<List<UserModel>> get participantsStream;
  Stream<String> get statusStream;
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
  TranscriptStreamServiceImpl({
    required SignalRService signalRService,
    required AuthLocalDataSource authLocalDataSource,
  }) : _signalRService = signalRService,
       _authLocalDataSource = authLocalDataSource;

  final SignalRService _signalRService;
  final AuthLocalDataSource _authLocalDataSource;
  final List<UserModel> _activeParticipants = [];
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<List<UserModel>> _participantsController =
      StreamController<List<UserModel>>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get transcriptStream => _transcriptController.stream;

  @override
  Stream<List<UserModel>> get participantsStream =>
      _participantsController.stream;

  @override
  Stream<String> get statusStream => _statusController.stream;

  UserModel _parseUser(Map<String, dynamic> item) {
    final hasJoinedAt = (item['joinedAt'] ?? item['JoinedAt']) != null;
    final isJoinedFlag = item['isJoined'] ?? item['IsJoined'];

    // Default to TRUE if ID exists, unless explicitly told otherwise.
    // This ensures we don't miss participants in different backend environments.
    bool joined = true;
    if (isJoinedFlag is bool) {
      joined = isJoinedFlag;
    } else if (hasJoinedAt) {
      joined = true;
    }

    return UserModel(
      id:
          (item['userId'] ?? item['UserId'] ?? item['id'] ?? item['Id'])
              ?.toString() ??
          '',
      email: (item['email'] ?? item['Email'] ?? '').toString(),
      displayName:
          (item['name'] ??
                  item['Name'] ??
                  item['userName'] ??
                  item['UserName'] ??
                  item['displayName'] ??
                  item['DisplayName'] ??
                  'User')
              .toString(),
      avatarUrl: (item['avatarUrl'] ?? item['AvatarUrl'])?.toString(),
      isJoined: joined,
    );
  }

  void _pushParticipants() {
    _participantsController.add(List.unmodifiable(_activeParticipants));
  }

  @override
  Future<void> connect(
    String url, {
    required String meetingId,
    List<dynamic>? initialRawParticipants,
  }) async {
    try {
      await _signalRService.connect(
        url,
        accessTokenFactory: () async =>
            _authLocalDataSource.getAccessToken() ?? '',
      );

      _signalRService.on('ReceiveLiveTranscript', (args) {
        if (args == null || args.isEmpty || args.first is! Map) return;
        final data = Map<String, dynamic>.from(args.first as Map);
        final text = data['text'] as String?;
        if (text != null && text.isNotEmpty) {
          _transcriptController.add(text);
        }
      });

      // ─── Helper: get a meeting object from payload root ─────────────────
      Map<String, dynamic>? _getMeetingObj(Map<String, dynamic> root) {
        final obj =
            root['updatedMeeting'] ??
            root['UpdatedMeeting'] ??
            root['meeting'] ??
            root['Meeting'];
        return obj is Map ? Map<String, dynamic>.from(obj) : null;
      }

      // ─── Strategy A: full list replacement ──────────────────────────────
      void handleFullList(List<Object?>? args) {
        if (args == null || args.isEmpty || args.first is! Map) return;
        final root = Map<String, dynamic>.from(args.first as Map);
        print('🔵 [handleFullList] raw root keys: ${root.keys.toList()}');
        final meetingObj = _getMeetingObj(root);
        if (meetingObj != null) {
          print(
            '🔵 [handleFullList] meetingObj keys: ${meetingObj.keys.toList()}',
          );
        }

        dynamic rawList = root['participants'] ?? root['Participants'];
        if (rawList == null && meetingObj != null) {
          rawList = meetingObj['participants'] ?? meetingObj['Participants'];
        }

        if (rawList is List) {
          print('🔵 [handleFullList] participants count: ${rawList.length}');
          for (final p in rawList.whereType<Map>()) {
            print('  → participant: ${Map<String, dynamic>.from(p)}');
          }
          // Filter by isJoined (derived from joinedAt != null).
          // Backend sends ALL invited participants; only those with joinedAt are active.
          final incoming = rawList
              .map((item) {
                if (item is Map) {
                  return _parseUser(Map<String, dynamic>.from(item));
                } else if (item is String) {
                  // If it's just an ID, create a simple user model
                  return UserModel(
                    id: item,
                    email: '',
                    displayName: 'User $item',
                    isJoined: true,
                  );
                }
                return null;
              })
              .whereType<UserModel>()
              .where((u) => u.isJoined && u.id.isNotEmpty)
              .toList();

          // Preserve any participant already marked locally as joined
          // but missing from the server payload (e.g., current user)
          final existingIds = incoming.map((u) => u.id).toSet();
          final preserved = _activeParticipants
              .where((u) => !existingIds.contains(u.id))
              .toList();

          _activeParticipants
            ..clear()
            ..addAll(incoming)
            ..addAll(preserved);
          _pushParticipants();
        }

        // Check status inside the same payload
        final statusRaw =
            root['status'] ??
            root['Status'] ??
            root['meetingStatus'] ??
            root['MeetingStatus'] ??
            (meetingObj != null
                ? meetingObj['status'] ?? meetingObj['Status']
                : null);
        if (statusRaw != null) {
          final s = statusRaw.toString();
          if (s.toLowerCase() == 'ended' || s == '2') {
            _statusController.add('Ended');
          } else {
            _statusController.add(s);
          }
        }
      }

      // ─── Strategy B: single-user join ───────────────────────────────────
      void handleSingleJoin(List<Object?>? args) {
        if (args == null || args.isEmpty) return;
        print('🟢 [ParticipantJoined] args: $args');

        // Payload may be a Map (single user) or come with updatedMeeting (full list)
        if (args.first is Map) {
          final root = Map<String, dynamic>.from(args.first as Map);
          final meetingObj = _getMeetingObj(root);

          // If full list available, prefer it
          final rawList =
              (meetingObj?['participants'] ??
              meetingObj?['Participants'] ??
              root['participants'] ??
              root['Participants']);
          if (rawList is List) {
            handleFullList(args);
            return;
          }

          // Otherwise treat root as the single joining user
          final user = _parseUser(root);
          if (user.id.isNotEmpty) {
            _activeParticipants.removeWhere((u) => u.id == user.id);
            _activeParticipants.add(user.copyWith(isJoined: true));
            _pushParticipants();
          }
        } else if (args.first is String) {
          // Backend sent just the User ID
          final userId = args.first.toString();
          if (userId.isNotEmpty) {
            _activeParticipants.removeWhere((u) => u.id == userId);
            _activeParticipants.add(
              UserModel(
                id: userId,
                email: '',
                displayName: 'User $userId',
                isJoined: true,
              ),
            );
            _pushParticipants();
          }
        }
      }

      // ─── Strategy B: single-user leave ──────────────────────────────────
      void handleSingleLeave(List<Object?>? args) {
        if (args == null || args.isEmpty) return;
        print('🔴 [ParticipantLeft] args: $args');

        if (args.first is Map) {
          final root = Map<String, dynamic>.from(args.first as Map);
          final meetingObj = _getMeetingObj(root);

          // If full list available, prefer it
          final rawList =
              (meetingObj?['participants'] ??
              meetingObj?['Participants'] ??
              root['participants'] ??
              root['Participants']);
          if (rawList is List) {
            handleFullList(args);
            return;
          }

          // Otherwise identify the leaving user by id
          final userId =
              (root['userId'] ?? root['UserId'] ?? root['id'] ?? root['Id'])
                  ?.toString();
          if (userId != null && userId.isNotEmpty) {
            _activeParticipants.removeWhere((u) => u.id == userId);
            _pushParticipants();
          }
        } else if (args.first is String) {
          final userId = args.first.toString();
          if (userId.isNotEmpty) {
            _activeParticipants.removeWhere((u) => u.id == userId);
            _pushParticipants();
          }
        }
      }

      // ─── Register all event names the backend might send ────────────────
      _signalRService.on('DatabaseParticipantJoined', handleSingleJoin);
      _signalRService.on('ParticipantJoined', handleSingleJoin);
      _signalRService.on('UserJoined', handleSingleJoin);
      _signalRService.on('DatabaseParticipantLeft', handleSingleLeave);
      _signalRService.on('ParticipantLeft', handleSingleLeave);
      _signalRService.on('UserLeft', handleSingleLeave);

      _signalRService.on('MeetingEnded', _handleMeetingEnded);
      _signalRService.on('MeetingEnd', _handleMeetingEnded);
      _signalRService.on('OnMeetingEnded', _handleMeetingEnded);
      _signalRService.on('ReceiveMeetingStatus', (args) {
        if (args != null && args.isNotEmpty) {
          final status = args.first.toString();
          if (status.toLowerCase() == 'ended' || status == '2') {
            _statusController.add('Ended');
          } else {
            _statusController.add(status);
          }
        }
      });
      _signalRService.on('MeetingStatusUpdated', (args) {
        if (args != null && args.isNotEmpty) {
          final raw = args.first;
          final status = (raw is Map ? raw['status'] : raw).toString();
          if (status.toLowerCase() == 'ended' || status == '2') {
            _statusController.add('Ended');
          } else {
            _statusController.add(status);
          }
        }
      });

      // ─── Initial state from JoinMeeting response ────────────────────────
      final result = await _signalRService.invoke(
        'JoinMeeting',
        args: [meetingId],
      );
      print('⚡ [JoinMeeting] response: $result');
      if (result != null) {
        handleFullList([result]);
      } else if (initialRawParticipants != null) {
        // Fallback: Using REST API participants since SignalR returned null
        print('⚡ [JoinMeeting] Using initialRawParticipants fallback');
        handleFullList([
          {'participants': initialRawParticipants},
        ]);
      }
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
      await _signalRService.invoke(
        'SendLiveTranscriptChunk',
        args: [
          {
            'meetingId': meetingId,
            'speakerName': speakerName,
            'text': text,
            'startTime': startTime,
            'endTime': endTime,
          },
        ],
      );
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

  void _handleMeetingEnded(List<Object?>? args) {
    if (args != null && args.isNotEmpty && args.first is Map) {
      final data = Map<String, dynamic>.from(args.first as Map);
      final name =
          (data['EndedByUserName'] ?? data['endedByUserName'] ?? data['name'])
              ?.toString();
      if (name != null) {
        _statusController.add('Ended by $name');
        return;
      }
    }
    _statusController.add('Ended');
  }
}
