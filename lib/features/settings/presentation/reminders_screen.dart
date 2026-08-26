import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';

/// Everything the user has asked to be reminded about.
///
/// The guide can only cancel a reminder from the exact programme cell that set
/// it, which is fine at 20:00 and useless a day later — this is the list you go
/// to when you cannot remember what you set.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  static String _when(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final delta = day.difference(today).inDays;
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return switch (delta) {
      0 => 'Today at $time',
      1 => 'Tomorrow at $time',
      _ => '${local.day}/${local.month} at $time',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(upcomingRemindersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: reminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('$e', style: TextStyle(color: AppColors.error))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_outlined,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('No reminders set.'),
                    const SizedBox(height: 4),
                    Text(
                      'Open the TV Guide and pick a programme that has not '
                      'started yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final reminder = list[i];
              return ListTile(
                autofocus: i == 0,
                leading: Icon(Icons.notifications_active,
                    color: AppColors.accent),
                title: Text(reminder.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${_when(reminder.startsAt)} · ${reminder.channelName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                trailing: IconButton(
                  tooltip: 'Cancel reminder',
                  icon: const Icon(Icons.close),
                  onPressed: () => _cancel(ref, reminder),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _cancel(WidgetRef ref, Reminder reminder) async {
    await ref.read(reminderServiceProvider).cancel(reminder);
    await ref.read(remindersRepositoryProvider).remove(reminder.id);
    ref.invalidate(upcomingRemindersProvider);
  }
}
