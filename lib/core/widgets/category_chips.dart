import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../domain/models/models.dart';
import '../matching/category_label.dart';
import 'focus_highlight.dart';

/// Horizontal category filter: optional pinned entries, then "All", then one
/// chip per category.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.leading = const [],
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  /// Pinned chips shown BEFORE "All" — used for the Favourites shortcut, which
  /// has no catalogue category behind it.
  final List<({String id, String label})> leading;

  @override
  Widget build(BuildContext context) {
    // (id, label) for every chip, in display order.
    final entries = <({String? id, String label})>[
      for (final l in leading) (id: l.id, label: l.label),
      (id: null, label: 'All'),
      for (final c in categories)
        (id: c.id, label: prettyCategoryName(c.name)),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final entry = entries[i];
          final selected = selectedId == entry.id;
          // FocusHighlight rather than a bare Focus + ensureVisible: it gives
          // the chip a ring the remote can actually see, and — the subtle part —
          // it scrolls the RIGHT thing. `Scrollable.ensureVisible(context)` with
          // the itemBuilder's own context targets the ListView's sliver element,
          // not this chip, so it yanked the row to one fixed offset. Being a
          // StatefulWidget, FocusHighlight's context resolves to its own
          // element, i.e. the chip.
          return FocusHighlight(
            borderRadius: 20,
            scale: 1.0,
            ensureVisible: true,
            child: ChoiceChip(
              label: Text(entry.label),
              selected: selected,
              onSelected: (_) => onSelected(entry.id),
              selectedColor: AppColors.accent.withValues(alpha: 0.28),
              side: BorderSide(
                  color:
                      selected ? AppColors.accent : AppColors.surfaceElevated),
            ),
          );
        },
      ),
    );
  }
}
