import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeting_brain/l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/dashboard_scaffold.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Mock data for grouping
    final meetingsWithTasks = [
      {
        'title': 'Product Sync - Weekly',
        'date': 'Oct 24, 2023',
        'tasks': [
          {'id': 't1', 'title': 'Prepare Weekly Summary', 'completed': false},
          {'id': 't2', 'title': 'Send Client Recap', 'completed': true},
        ]
      },
      {
        'title': 'Design Review',
        'date': 'Oct 22, 2023',
        'tasks': [
          {'id': 't3', 'title': 'Update UI Mockups', 'completed': false},
          {'id': 't4', 'title': 'Feedback Implementation', 'completed': false},
        ]
      },
      {
        'title': 'Backend Planning',
        'date': 'Oct 20, 2023',
        'tasks': [
          {'id': 't5', 'title': 'API Documentation', 'completed': true},
        ]
      },
      {
        'title': 'Marketing Strategy',
        'date': 'Oct 18, 2023',
        'tasks': [
          {'id': 't6', 'title': 'Social Media Plan', 'completed': false},
          {'id': 't7', 'title': 'Ad Spend Review', 'completed': false},
        ]
      },
    ];

    return DashboardScaffold(
      title: l10n.tasksTitle,
      subtitle: l10n.tasksSubtitle,
      currentRoute: '/tasks',
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: meetingsWithTasks.length,
        itemBuilder: (context, index) {
          final group = meetingsWithTasks[index];
          final tasks = group['tasks'] as List<Map<String, dynamic>>;

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
                  group['title'] as String,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${tasks.length} tasks • ${group['date']}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: tasks.map((task) {
                  return _TaskItem(
                    title: task['title'] as String,
                    completed: task['completed'] as bool,
                    onTap: () => context.push('/tasks/details/${task['id']}'),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  const _TaskItem({required this.title, required this.completed, this.onTap});

  final String title;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CheckboxListTile(
          title: Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              decoration: completed ? TextDecoration.lineThrough : null,
              color: completed ? theme.colorScheme.onSurface.withOpacity(0.4) : null,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: completed,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: theme.colorScheme.primary,
          checkColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onChanged: (_) {},
        ),
      ),
    );
  }
}
