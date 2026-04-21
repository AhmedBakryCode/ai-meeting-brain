import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:meeting_brain/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/dashboard_scaffold.dart';
import '../../../../core/di/injection_container.dart';
import '../cubit/tasks_cubit.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TasksCubit>()..fetchMeetings(),
      child: const _TasksPageContent(),
    );
  }
}

class _TasksPageContent extends StatelessWidget {
  const _TasksPageContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return DashboardScaffold(
      title: l10n.tasksTitle,
      subtitle: l10n.tasksSubtitle,
      currentRoute: '/tasks',
      body: BlocBuilder<TasksCubit, TasksState>(
        builder: (context, state) {
          if (state.meetingsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.meetingsError != null) {
            return Center(child: Text(state.meetingsError!, style: TextStyle(color: theme.colorScheme.error)));
          }

          final meetings = state.meetings;
          
          if (meetings.isEmpty) {
            return const Center(child: Text('No meetings found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: meetings.length,
            itemBuilder: (context, index) {
              final meeting = meetings[index];
              final meetingId = meeting.id;
              final tasks = state.tasksByMeeting[meetingId] ?? [];
              final isLoading = state.tasksLoading[meetingId] ?? false;
              final error = state.tasksErrors[meetingId];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    onExpansionChanged: (expanded) {
                      if (expanded) {
                        context.read<TasksCubit>().fetchTasksForMeeting(meetingId);
                      }
                    },
                    iconColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.primary,
                    collapsedIconColor: theme.colorScheme.onSurface.withOpacity(0.3),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.video_call_rounded, color: theme.colorScheme.primary, size: 22),
                    ),
                    title: Text(
                      meeting.title.isEmpty ? 'Meeting ${index + 1}' : meeting.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      state.tasksByMeeting.containsKey(meetingId)
                          ? '${tasks.length} tasks'
                          : 'Click to load tasks',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (error != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
                        )
                      else if (tasks.isEmpty && state.tasksByMeeting.containsKey(meetingId))
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('No tasks for this meeting', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                        )
                      else
                        ...tasks.map((task) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _TaskItem(
                              title: task.title,
                              completed: task.isDone,
                              date: task.dueDate,
                              onChanged: task.isDone 
                                  ? null 
                                  : (value) {
                                      if (value == true) {
                                        context.read<TasksCubit>().completeTask(meetingId, task.id);
                                      }
                                    },
                              onTap: task.isDone 
                                  ? null 
                                  : () => context.push('/tasks/details/${task.id}'),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  const _TaskItem({
    required this.title,
    required this.completed,
    this.date,
    this.onTap,
    this.onChanged,
  });

  final String title;
  final bool completed;
  final DateTime? date;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: completed 
            ? theme.colorScheme.onSurface.withOpacity(0.02)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: completed 
              ? theme.colorScheme.onSurface.withOpacity(0.05)
              : Colors.transparent,
        ),
        boxShadow: completed ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CheckboxListTile(
        enabled: !completed, // Disable the whole tile interaction if completed
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: completed ? TextDecoration.lineThrough : null,
            color: completed ? theme.colorScheme.onSurface.withOpacity(0.3) : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: date != null 
            ? Text(
                DateFormat('MMM d, yyyy h:mm a').format(date!), 
                style: theme.textTheme.bodySmall?.copyWith(
                  color: completed ? theme.colorScheme.onSurface.withOpacity(0.2) : null,
                ),
              ) 
            : null,
        value: completed,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: theme.colorScheme.primary,
        checkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onChanged: onChanged,
        secondary: !completed ? IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ) : null,
      ),
    );
  }
}
