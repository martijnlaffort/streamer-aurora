import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../domain/models/models.dart';
import '../matching/category_label.dart';

/// Horizontal category filter: "All" + one chip per category.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (id, label) = i == 0
              ? (null, 'All')
              : (
                  categories[i - 1].id,
                  prettyCategoryName(categories[i - 1].name)
                );
          final selected = selectedId == id;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onSelected(id),
            selectedColor: AppColors.accent.withValues(alpha: 0.28),
            side: BorderSide(
                color: selected ? AppColors.accent : AppColors.surfaceElevated),
          );
        },
      ),
    );
  }
}
