import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/services/webrtc_service.dart';
import '../bloc/meeting_bloc.dart';

class LiveMeetingPage extends StatelessWidget {
  const LiveMeetingPage({
    required this.meetingId,
    this.canUploadRecording = true,
    this.isJoinedParticipant = false,
    super.key,
  });
  final String meetingId;
  final bool canUploadRecording;
  final bool isJoinedParticipant;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MeetingBloc(
        recordingService: sl(),
        transcriptStreamService: sl(),
        webRtcService: sl(),
        meetingsRepository: sl(),
        authLocalDataSource: sl(),
        canUploadRecording: canUploadRecording,
      )..add(JoinMeeting(meetingId)),
      child: _LiveMeetingView(
        meetingId: meetingId,
        isJoinedParticipant: isJoinedParticipant,
      ),
    );
  }
}

class _LiveMeetingView extends StatefulWidget {
  const _LiveMeetingView({
    required this.meetingId,
    required this.isJoinedParticipant,
  });
  final String meetingId;
  final bool isJoinedParticipant;

  @override
  State<_LiveMeetingView> createState() => _LiveMeetingViewState();
}

class _LiveMeetingViewState extends State<_LiveMeetingView> {
  bool _speakerEnabled = true;

  Future<bool> _onWillPop() async {
    final state = context.read<MeetingBloc>().state;
    final isActive = state.isMicEnabled || state is Processing;

    if (!isActive) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave meeting?'),
        content: const Text('Recording will be stopped and saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () {
              if (widget.isJoinedParticipant) {
                context.read<MeetingBloc>().add(LeaveMeeting(widget.meetingId));
              } else {
                context.read<MeetingBloc>().add(EndMeeting(widget.meetingId));
              }
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave & Stop'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted && router.canPop()) {
          router.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: SafeArea(
          child: BlocConsumer<MeetingBloc, MeetingState>(
            listener: (context, state) {
              if (state is MeetingPermissionDenied) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Microphone permission denied.'),
                  ),
                );
              }
              if (state is Completed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.isJoinedParticipant
                          ? 'Left meeting successfully.'
                          : 'Meeting ended successfully.',
                    ),
                  ),
                );
                GoRouter.of(context).go('/meetings');
              }
              if (state is MeetingFailure) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
            builder: (context, state) {
              final isRecording = state.isMicEnabled;
              final isConnected =
                  state is! MeetingInitial && state is! MeetingFailure;
              final isProcessing = state is Processing;
              final isCompleted = state is Completed;
              final participants = _buildParticipants(state);
              final highlightedParticipant = participants.firstWhere(
                (participant) => participant.isActive,
                orElse: () => participants.first,
              );

              return Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: _MeetingHeader(
                          duration: state.elapsed,
                          statusLabel: _statusLabel(state),
                          onBack: () async {
                            final router = GoRouter.of(context);
                            final shouldPop = await _onWillPop();
                            if (shouldPop && mounted && router.canPop()) {
                              router.pop();
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GridView.builder(
                            padding: const EdgeInsets.only(bottom: 132),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      MediaQuery.sizeOf(context).width > 900
                                      ? 3
                                      : 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.68,
                                ),
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              final participant = participants[index];
                              return _ParticipantTile(
                                participant: participant,
                                isSpeakerEnabled: _speakerEnabled,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.transcripts.isNotEmpty)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 108,
                      child: _TranscriptCaptionCard(
                        speaker: highlightedParticipant.name,
                        text: state.transcripts.last,
                      ),
                    ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: _MeetingControls(
                      speakerEnabled: _speakerEnabled,
                      micEnabled: isRecording,
                      canToggleMic:
                          isConnected && !isProcessing && !isCompleted,
                      onToggleSpeaker: () {
                        setState(() {
                          _speakerEnabled = !_speakerEnabled;
                        });
                        // Actually control remote audio output
                        sl<WebRtcService>().setSpeakerEnabled(_speakerEnabled);
                      },
                      onToggleMic: () {
                        if (isConnected) {
                          context.read<MeetingBloc>().add(
                            ToggleMicrophone(widget.meetingId),
                          );
                        }
                      },
                      onEndMeeting: () {
                        if (widget.isJoinedParticipant) {
                          context.read<MeetingBloc>().add(
                            LeaveMeeting(widget.meetingId),
                          );
                        } else {
                          context.read<MeetingBloc>().add(
                            EndMeeting(widget.meetingId),
                          );
                        }
                      },
                      endLabel: widget.isJoinedParticipant
                          ? 'Leave meeting'
                          : 'End meeting',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_Participant> _buildParticipants(MeetingState state) {
    final participants = state.participants;
    if (participants.isEmpty) {
      return <_Participant>[
        _Participant(
          name: 'Waiting...',
          role: 'No participants yet',
          color: const Color(0xFF8B5CF6),
          initials: 'WA',
          isMicEnabled: state.isMicEnabled,
          isActive: true,
        ),
      ];
    }

    final activeIndex = state.transcripts.isEmpty
        ? 0
        : state.transcripts.length % participants.length;
    final palette = <Color>[
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
    ];

    return participants.asMap().entries.map((entry) {
      final index = entry.key;
      final user = entry.value;

      // Determine if this user is speaking based on real-time audio levels (from WebRTC stats)
      // Level is typically 0.0 to 1.0. 0.02 is a reasonable threshold for 'active'.
      final audioLevel = state.audioLevels[user.id] ?? 0.0;
      final isSpeaking = audioLevel > 0.02;

      return _participantFromUser(
        user,
        color: palette[index % palette.length],
        isActive: isSpeaking,
        isMicEnabled: index == 0 ? state.isMicEnabled : true, // Local mic status from state
      );
    }).toList();
  }

  _Participant _participantFromUser(
    UserModel user, {
    required Color color,
    required bool isActive,
    required bool isMicEnabled,
  }) {
    final cleanedName = user.displayName.trim().isEmpty
        ? 'Unknown user'
        : user.displayName.trim();
    final initials = cleanedName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    return _Participant(
      name: cleanedName,
      role: user.email,
      color: color,
      initials: initials.isEmpty ? 'US' : initials,
      isMicEnabled: isMicEnabled,
      isActive: isActive,
    );
  }

  String _statusLabel(MeetingState state) {
    if (state.isMicEnabled) return 'Live now';
    if (state is MeetingJoined && state.isLoading) return 'Connecting';
    if (state is MeetingJoined) return 'Connected';
    if (state is Processing) return 'Ending';
    if (state is Completed) return 'Finished';
    if (state is MeetingFailure) return 'Error';
    return 'Preparing';
  }
}

class _MeetingHeader extends StatelessWidget {
  const _MeetingHeader({
    required this.duration,
    required this.statusLabel,
    required this.onBack,
  });

  final Duration duration;
  final String statusLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live Meeting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _StatusDot(label: statusLabel),
                  const SizedBox(width: 10),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                'Gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(duration.inHours);
    final m = twoDigits(duration.inMinutes.remainder(60));
    final s = twoDigits(duration.inSeconds.remainder(60));
    return '$h:$m:$s';
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.isSpeakerEnabled,
  });

  final _Participant participant;
  final bool isSpeakerEnabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            participant.color.withValues(
              alpha: participant.isActive ? 0.35 : 0.18,
            ),
            const Color(0xFF0F172A),
          ],
        ),
        border: Border.all(
          color: participant.isActive
              ? participant.color.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: participant.color.withValues(
              alpha: participant.isActive ? 0.25 : 0.08,
            ),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        participant.isMicEnabled
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        participant.isMicEnabled ? 'Mic on' : 'Mic off',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (participant.isActive)
                  Icon(
                    isSpeakerEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
              ],
            ),
            const Spacer(),
            const Spacer(),
            Expanded(
              flex: 8,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: _AvatarWave(
                    color: participant.color,
                    initials: participant.initials,
                    isActive: participant.isActive,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              participant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              participant.role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarWave extends StatefulWidget {
  const _AvatarWave({
    required this.color,
    required this.initials,
    required this.isActive,
  });

  final Color color;
  final String initials;
  final bool isActive;

  @override
  State<_AvatarWave> createState() => _AvatarWaveState();
}

class _AvatarWaveState extends State<_AvatarWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var index = 0; index < 3; index++)
                _WaveRing(
                  progress: (_controller.value + (index * 0.24)) % 1,
                  color: widget.color,
                  visible: widget.isActive,
                ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.color.withValues(alpha: 0.95),
                      widget.color.withValues(alpha: 0.55),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WaveRing extends StatelessWidget {
  const _WaveRing({
    required this.progress,
    required this.color,
    required this.visible,
  });

  final double progress;
  final Color color;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final scale = 1 + (progress * 0.55);
    final opacity = visible ? (1 - progress).clamp(0.0, 1.0) * 0.45 : 0.0;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 102,
        height: 102,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: opacity),
            width: math.max(1.5, 3 - (progress * 2)),
          ),
        ),
      ),
    );
  }
}

class _TranscriptCaptionCard extends StatelessWidget {
  const _TranscriptCaptionCard({required this.speaker, required this.text});

  final String speaker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: '$speaker: ',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            TextSpan(
              text: text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingControls extends StatelessWidget {
  const _MeetingControls({
    required this.speakerEnabled,
    required this.micEnabled,
    required this.canToggleMic,
    required this.onToggleSpeaker,
    required this.onToggleMic,
    required this.onEndMeeting,
    required this.endLabel,
  });

  final bool speakerEnabled;
  final bool micEnabled;
  final bool canToggleMic;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleMic;
  final VoidCallback onEndMeeting;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ControlButton(
              icon: speakerEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              label: speakerEnabled ? 'Speaker on' : 'Speaker off',
              onPressed: onToggleSpeaker,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ControlButton(
              icon: micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
              label: micEnabled ? 'Mic on' : 'Mic off',
              onPressed: canToggleMic ? onToggleMic : null,
              isActive: micEnabled,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ControlButton(
              icon: Icons.call_end_rounded,
              label: endLabel,
              onPressed: onEndMeeting,
              backgroundColor: const Color(0xFFE5484D),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final baseColor =
        backgroundColor ??
        (isActive
            ? const Color(0xFF8B5CF6)
            : Colors.white.withValues(alpha: 0.1));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Participant {
  const _Participant({
    required this.name,
    required this.role,
    required this.color,
    required this.initials,
    required this.isMicEnabled,
    required this.isActive,
  });

  final String name;
  final String role;
  final Color color;
  final String initials;
  final bool isMicEnabled;
  final bool isActive;
}
