import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shell_actions.dart';
import '../providers_providers.dart';

/// Browse by streaming service.
///
/// A line already organises its VOD by service — it just does it inside
/// category names, so the app saw `NL | NETFLIX`, `MULTI | NETFLIX 4K` and
/// `VOD | NETFLIX SERIES` as three unrelated strings. This is the same
/// catalogue addressed the way people actually think about it.
class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(providerShelvesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Providers'),
        actions: const [ShellActions()],
      ),
      body: shelves.when(
        // A background sync must never blank a screen that already has content.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
            error: e, onRetry: () => ref.invalidate(providerShelvesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apps_outlined,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('No streaming services recognised.'),
                    const SizedBox(height: 4),
                    Text(
                      'This playlist does not name its categories after '
                      'services like Netflix or Disney+. Browse by category on '
                      'the Movies and Series tabs instead.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async => ref.invalidate(providerShelvesProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 1.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) => _ProviderTile(
                shelf: list[i],
                autofocus: i == 0,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProviderTile extends StatefulWidget {
  const _ProviderTile({required this.shelf, this.autofocus = false});

  final ProviderShelf shelf;
  final bool autofocus;

  @override
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile> {
  bool _engaged = false;

  @override
  Widget build(BuildContext context) {
    final brand = widget.shelf.brand;
    // The brand's own colour rather than its logo: shipping the real marks
    // would mean bundling other people's trademarks into the app.
    final color = Color(brand.colorValue);
    return InkWell(
      autofocus: widget.autofocus,
      borderRadius: BorderRadius.circular(12),
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onFocusChange: (f) => setState(() => _engaged = f),
      onHover: (h) => setState(() => _engaged = h),
      onTap: () => context.push('/providers/${brand.id}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.95),
              Color.lerp(color, Colors.black, 0.45)!,
            ],
          ),
          border: Border.all(
            color: _engaged ? AppColors.focusRing : Colors.transparent,
            width: 3,
          ),
          boxShadow: _engaged
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 18,
                      spreadRadius: 1),
                ]
              : const [],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              brand.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              _summary(widget.shelf),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Says what the tile leads to, in categories rather than titles: a title
  /// count would need the whole catalogue warmed, which is exactly the request
  /// storm the lazy per-category cache exists to avoid.
  static String _summary(ProviderShelf shelf) {
    final parts = <String>[
      if (shelf.movieCategories.isNotEmpty)
        '${shelf.movieCategories.length} film '
            'group${shelf.movieCategories.length == 1 ? '' : 's'}',
      if (shelf.seriesCategories.isNotEmpty)
        '${shelf.seriesCategories.length} series '
            'group${shelf.seriesCategories.length == 1 ? '' : 's'}',
    ];
    return parts.join(' · ');
  }
}
