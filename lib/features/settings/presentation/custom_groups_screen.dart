import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/catalog_overrides_repository.dart';
import '../../../domain/models/models.dart';
import '../../live/live_providers.dart';

/// The channel groups the user made: rename, delete, and see what is in them.
///
/// Groups are BUILT from the Live tab (the channel menu's "Add to group…"),
/// because that is where you are when you decide a channel belongs somewhere.
/// This is where you come to tidy them up afterwards.
class CustomGroupsScreen extends ConsumerWidget {
  const CustomGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides =
        ref.watch(catalogOverridesProvider).value ?? CatalogOverrides.empty;
    final groups = overrides.orderedGroups;

    return Scaffold(
      appBar: AppBar(title: const Text('Channel groups')),
      body: groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_outlined,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('No groups yet.'),
                    const SizedBox(height: 4),
                    Text(
                      'On Live TV, open a channel\'s menu and choose '
                      '"Add to group" to make one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final g = groups[i];
                final count = overrides.groupMembers[g.id]?.length ?? 0;
                return ListTile(
                  autofocus: i == 0,
                  leading: Icon(Icons.folder_outlined, color: AppColors.accent),
                  title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$count channel${count == 1 ? '' : 's'}',
                      style: TextStyle(color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => _GroupDetail(groupId: g.id))),
                );
              },
            ),
    );
  }
}

class _GroupDetail extends ConsumerWidget {
  const _GroupDetail({required this.groupId});

  final String groupId;

  Future<void> _rename(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    await ref.read(catalogOverridesRepositoryProvider).renameGroup(
        accountId: account.id, groupId: groupId, name: name);
    ref.invalidate(catalogOverridesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('The channels themselves are not affected.'),
        actions: [
          TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    await ref.read(catalogOverridesRepositoryProvider).deleteGroup(
        accountId: account.id, groupId: groupId);
    ref.invalidate(catalogOverridesProvider);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides =
        ref.watch(catalogOverridesProvider).value ?? CatalogOverrides.empty;
    final group = overrides.customGroups[groupId];
    final memberIds = overrides.groupMembers[groupId] ?? const <String>[];
    final channels = ref.watch(groupChannelsProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Group'),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: group == null ? null : () => _rename(context, ref, group.name),
          ),
          IconButton(
            tooltip: 'Delete group',
            icon: const Icon(Icons.delete_outline),
            onPressed: group == null ? null : () => _delete(context, ref, group.name),
          ),
        ],
      ),
      body: memberIds.isEmpty
          ? Center(
              child: Text('Nothing in this group yet.',
                  style: TextStyle(color: AppColors.textSecondary)))
          : channels.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('$e', style: TextStyle(color: AppColors.error))),
              data: (list) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    autofocus: i == 0,
                    leading: Icon(Icons.live_tv, color: AppColors.textSecondary),
                    title: Text(overrides.channelName(c.id, c.displayName),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'Remove from group',
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        final account =
                            await ref.read(activeAccountProvider.future);
                        if (account == null) return;
                        await ref
                            .read(catalogOverridesRepositoryProvider)
                            .removeFromGroup(
                                accountId: account.id,
                                groupId: groupId,
                                channelId: c.id);
                        ref.invalidate(catalogOverridesProvider);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Sheet: pick an existing group or make a new one for [channel].
Future<void> addChannelToGroup(
    BuildContext context, WidgetRef ref, Channel channel) async {
  final account = await ref.read(activeAccountProvider.future);
  if (account == null || !context.mounted) return;
  final overrides = await ref.read(catalogOverridesProvider.future);
  if (!context.mounted) return;
  final groups = overrides.orderedGroups;
  final memberOf = {
    for (final g in groups)
      if ((overrides.groupMembers[g.id] ?? const []).contains(channel.id)) g.id,
  };

  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Add to group',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title),
            ),
          ),
          for (final (i, g) in groups.indexed)
            ListTile(
              autofocus: i == 0,
              leading: Icon(
                memberOf.contains(g.id)
                    ? Icons.check_circle
                    : Icons.folder_outlined,
                color: memberOf.contains(g.id)
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              title: Text(g.name),
              subtitle: memberOf.contains(g.id)
                  ? Text('Already in this group',
                      style: TextStyle(color: AppColors.textSecondary))
                  : null,
              onTap: () => Navigator.pop(sheetContext, g.id),
            ),
          ListTile(
            autofocus: groups.isEmpty,
            leading: const Icon(Icons.add),
            title: const Text('New group…'),
            onTap: () => Navigator.pop(sheetContext, ''),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;

  final repo = ref.read(catalogOverridesRepositoryProvider);
  var groupId = picked;
  if (picked.isEmpty) {
    final controller = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Sports, Kids, News…'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    groupId = await repo.createGroup(accountId: account.id, name: name);
  } else if (memberOf.contains(picked)) {
    return; // Already there; nothing to do.
  }
  await repo.addToGroup(
      accountId: account.id, groupId: groupId, channelId: channel.id);
  ref.invalidate(catalogOverridesProvider);
  if (context.mounted) {
    final label = overrides.customGroups[groupId]?.name ?? 'the group';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Added to $label.')));
  }
}
