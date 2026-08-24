import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/matching/category_label.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/db/app_database.dart' show OverrideScope;
import '../../../data/repositories/catalog_overrides_repository.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';

/// Hide, rename and reorder the groups a playlist ships with.
///
/// A real line arrives with hundreds of categories, most of which a given
/// household never wants — and the panel decides both the names and the order.
/// This is where the user overrules that. Nothing here touches the cached
/// catalogue: a refresh replaces those rows wholesale, so the edits live in
/// their own table beside them.
class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key, required this.type});

  final CategoryType type;

  String get _title => switch (type) {
        CategoryType.live => 'Live TV groups',
        CategoryType.vod => 'Movie groups',
        CategoryType.series => 'Series groups',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The RAW list, not the filtered one: you cannot unhide something that has
    // been filtered out of the list you are editing.
    final categories = ref.watch(_allCategoriesProvider(type));
    final overrides =
        ref.watch(catalogOverridesProvider).value ?? CatalogOverrides.empty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (!overrides.isEmpty)
            TextButton(
              onPressed: () => _resetAll(context, ref),
              child: const Text('Reset'),
            ),
        ],
      ),
      body: categories.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(_allCategoriesProvider(type))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('This playlist has no groups yet.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }
          // Shown in the user's own order so dragging is predictable.
          final ordered = overrides.applyToCategories<Category>(
            list,
            idOf: (c) => c.id,
          );
          // applyToCategories drops hidden ones; this screen has to show them.
          final hidden = [
            for (final c in list)
              if (overrides.hiddenCategories.contains(c.id)) c,
          ];
          final rows = [...ordered, ...hidden];

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'Drag to reorder. Hidden groups disappear from browsing, '
                  'search and the guide — nothing is deleted.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  // onReorderItem, not the deprecated onReorder: it hands back
                  // an index already adjusted for the removed item, so the
                  // off-by-one dance the old callback needed is gone.
                  onReorderItem: (from, to) => _reorder(ref, rows, from, to),
                  itemBuilder: (context, i) {
                    final category = rows[i];
                    final isHidden =
                        overrides.hiddenCategories.contains(category.id);
                    final custom = overrides.categoryNames[category.id];
                    return ListTile(
                      key: ValueKey(category.id),
                      leading: IconButton(
                        tooltip: isHidden ? 'Show' : 'Hide',
                        icon: Icon(
                          isHidden ? Icons.visibility_off : Icons.visibility,
                          color: isHidden
                              ? AppColors.textSecondary
                              : AppColors.accentAlt,
                        ),
                        onPressed: () => _setHidden(ref, category, !isHidden),
                      ),
                      title: Text(
                        custom ?? prettyCategoryName(category.name),
                        style: TextStyle(
                          color: isHidden
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration:
                              isHidden ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      // The panel's own name, so a rename is never a mystery.
                      subtitle: custom == null
                          ? null
                          : Text(category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                      trailing: IconButton(
                        tooltip: 'Rename',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _rename(context, ref, category, custom),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _setHidden(
      WidgetRef ref, Category category, bool hidden) async {
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    await ref.read(catalogOverridesRepositoryProvider).setHidden(
          accountId: account.id,
          scope: OverrideScope.category,
          targetId: category.id,
          hidden: hidden,
        );
    ref.invalidate(catalogOverridesProvider);
  }

  Future<void> _reorder(
      WidgetRef ref, List<Category> rows, int from, int to) async {
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    final ids = [for (final c in rows) c.id];
    final moved = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), moved);
    await ref
        .read(catalogOverridesRepositoryProvider)
        .setCategoryOrder(accountId: account.id, orderedIds: ids);
    ref.invalidate(catalogOverridesProvider);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Category category,
      String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: prettyCategoryName(category.name),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          // Empty restores the panel's own name, so there is no separate
          // "clear" action to find.
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Use original'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    await ref.read(catalogOverridesRepositoryProvider).setName(
          accountId: account.id,
          scope: OverrideScope.category,
          targetId: category.id,
          name: name,
        );
    ref.invalidate(catalogOverridesProvider);
  }

  Future<void> _resetAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all group changes?'),
        content: const Text(
            'Hidden, renamed and reordered groups all go back to what the '
            'playlist says. Channel changes are kept.'),
        actions: [
          TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    await ref.read(catalogOverridesRepositoryProvider).clearAll(account.id);
    ref.invalidate(catalogOverridesProvider);
  }
}

/// Every category the playlist has, unfiltered — this screen edits the filter,
/// so it cannot be subject to it.
final _allCategoriesProvider =
    FutureProvider.family<List<Category>, CategoryType>((ref, type) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  return ref.watch(catalogRepositoryProvider).categories(account, type);
});

/// `CatalogOverrides.empty` is referenced from a widget file that should not
/// import the repository directly; this keeps the dependency at one name.
