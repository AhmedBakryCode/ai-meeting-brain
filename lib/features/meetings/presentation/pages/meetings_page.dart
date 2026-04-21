import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeting_brain/l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/widgets/dashboard_scaffold.dart';
import '../../data/datasources/meetings_remote_data_source.dart';
import '../../domain/entities/meeting_entity.dart';
import '../../domain/repositories/meetings_repository.dart';
import 'package:meeting_brain/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:meeting_brain/features/auth/data/models/user_model.dart';
import 'package:meeting_brain/features/auth/data/datasources/auth_local_data_source.dart';

class MeetingsPage extends StatefulWidget {
  final MeetingsRemoteDataSource remoteDataSource;

  const MeetingsPage({super.key, required this.remoteDataSource});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  final MeetingsRepository _repository = sl<MeetingsRepository>();
  final MeetingsRemoteDataSource _remote = sl<MeetingsRemoteDataSource>();
  final ScrollController _scrollController = ScrollController();
  final List<MeetingEntity> _meetings = <MeetingEntity>[];

  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPage();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadPage();
      }
    });
  }


  Future<void> _loadPage() async {
    setState(() => _isLoading = true);
    final result = await _repository.getMeetings(page: _page, limit: 10);
    final authDataSource = sl<AuthLocalDataSource>();
    final currentIdentifiers = authDataSource.extractUserIdentifiersFromToken(
      authDataSource.getAccessToken(),
    );
    final filteredItems = result.items.where((meeting) {
      return currentIdentifiers.contains(meeting.creatorId.trim().toLowerCase()) ||
          currentIdentifiers.contains(meeting.creatorName.trim().toLowerCase());
    }).toList();
    if (!mounted) return;
    setState(() {
      _meetings.addAll(filteredItems);
      _hasMore = result.hasMore;
      _isLoading = false;
      if (filteredItems.isNotEmpty) {
        _page += 1;
      }
    });
  }

  Future<void> _startAndOpenMeeting(
    BuildContext context,
    String meetingId,
    bool canUpload,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      if (canUpload) {
        await _remote.startMeeting(meetingId);
      } else {
        await _remote.joinMeeting(meetingId);
      }
      if (!mounted) return;
      router.push('/meetings/live/$meetingId?canUpload=$canUpload&joined=${!canUpload}');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to enter meeting: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _deleteMeeting(String meetingId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _repository.deleteMeeting(meetingId);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Meeting deleted successfully')),
      );
      // Refresh the list
      setState(() {
        _meetings.clear();
        _page = 1;
        _hasMore = true;
      });
      _loadPage();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to delete meeting: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return DashboardScaffold(
      title: l10n.meetingsTitle,
      subtitle: l10n.meetingsSubtitle,
      currentRoute: '/meetings',
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: InkWell(
                  onTap: () => _showCreateMeetingDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule New Meeting',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: _meetings.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    if (index >= _meetings.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final meeting = _meetings[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            if (meeting.status.toLowerCase() == 'ended') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This meeting has already ended and cannot be joined.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final authDataSource = sl<AuthLocalDataSource>();
                            final currentIdentifiers = authDataSource.extractUserIdentifiersFromToken(
                              authDataSource.getAccessToken(),
                            );
                            bool canUpload = currentIdentifiers.contains(meeting.creatorId.trim().toLowerCase()) ||
                                             currentIdentifiers.contains(meeting.creatorName.trim().toLowerCase());
                                             
                            _startAndOpenMeeting(
                              context,
                              meeting.id.isEmpty ? 'm_$index' : meeting.id,
                              canUpload,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  height: 56,
                                  width: 56,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.mic_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        Text(
                                          meeting.title.isEmpty
                                              ? '${l10n.meeting} ${index + 1}'
                                              : meeting.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            size: 14,
                                            color: theme.colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              l10n.aiSummaryPending,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.5),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (meeting.status.toLowerCase() == 'ended')
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteMeeting(meeting.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: theme.colorScheme.onSurface.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _showCreateMeetingDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      'Start Live Meeting',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateMeetingDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isCreating = false;
    List<UserModel> availableUsers = [];
    final List<String> selectedUserIds = [];
    bool isLoadingUsers = true;
    String? fetchError;
    StateSetter? dialogSetter;

    // Fetch users immediately
    sl<AuthRemoteDataSource>()
        .fetchUsers()
        .then((users) {
          availableUsers = users;
          isLoadingUsers = false;
          if (dialogSetter != null) dialogSetter!(() {});
        })
        .catchError((e) {
          isLoadingUsers = false;
          fetchError = 'Could not load users';
          if (dialogSetter != null) dialogSetter!(() {});
        });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            dialogSetter = setDialogState;
            final dateLabel =
                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}  '
                '${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: const Text('Start New Meeting'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    enabled: !isCreating,
                    decoration: const InputDecoration(
                      labelText: 'Meeting Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: isCreating
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(minutes: 5),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null && dialogContext.mounted) {
                              // Also pick time
                              final time = await showTimePicker(
                                context: dialogContext,
                                initialTime: TimeOfDay.fromDateTime(
                                  selectedDate,
                                ),
                              );
                              setDialogState(() {
                                selectedDate = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time?.hour ?? selectedDate.hour,
                                  time?.minute ?? selectedDate.minute,
                                );
                              });
                            }
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date & Time',
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(dateLabel),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Participants',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isLoadingUsers)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120, // List of users
                    width: double.maxFinite,
                    child: isLoadingUsers
                        ? const Center(child: CircularProgressIndicator())
                        : fetchError != null
                        ? Center(
                            child: Text(
                              fetchError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          )
                        : availableUsers.isEmpty
                        ? const Center(
                            child: Text(
                              'No users found',
                              style: TextStyle(fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: availableUsers.length,
                            itemBuilder: (context, index) {
                              final user = availableUsers[index];
                              final isSelected = selectedUserIds.contains(
                                user.id,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            selectedUserIds.remove(user.id);
                                          } else {
                                            selectedUserIds.add(user.id);
                                          }
                                        });
                                      },
                                      child: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: isSelected
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Colors.grey.withValues(
                                                    alpha: 0.2,
                                                  ),
                                            backgroundImage:
                                                user.avatarUrl != null
                                                ? NetworkImage(user.avatarUrl!)
                                                : null,
                                            child: user.avatarUrl == null
                                                ? Text(
                                                    user.displayName.isNotEmpty
                                                        ? user.displayName[0]
                                                              .toUpperCase()
                                                        : '?',
                                                  )
                                                : null,
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 64,
                                      child: Text(
                                        user.displayName,
                                        style: const TextStyle(fontSize: 10),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a meeting title'),
                              ),
                            );
                            return;
                          }
                          // Capture context-dependent objects BEFORE the async gap
                          final messenger = ScaffoldMessenger.of(context);
                          final router = GoRouter.of(context);
                          setDialogState(() => isCreating = true);
                          try {
                            final response = await _remote.createMeeting(
                              title: titleCtrl.text.trim(),
                              date: selectedDate,
                              participantIds: selectedUserIds,
                            );
                            // Safely extract meeting ID — server may use 'id' or 'meetingId'
                            final rawId =
                                response['id'] ?? response['meetingId'];
                            if (rawId == null || rawId.toString().isEmpty) {
                              throw Exception(
                                'Server returned no meeting ID. Response: $response',
                              );
                            }
                            final meetingId = rawId.toString();
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            // Reload list then navigate
                            setState(() {
                              _meetings.clear();
                              _page = 1;
                              _hasMore = true;
                            });
                            _loadPage();
                            await _remote.startMeeting(meetingId);
                            if (!mounted) return;
                            router.push(
                              '/meetings/live/$meetingId?canUpload=true',
                            );
                          } catch (e, stackTrace) {
                            print(
                              '=============== MEETING CREATION EXCEPTION ===============',
                            );
                            print(e.toString());
                            print(stackTrace.toString());
                            print(
                              '==========================================================',
                            );
                            setDialogState(() => isCreating = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to create meeting: $e'),
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create & Start'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
