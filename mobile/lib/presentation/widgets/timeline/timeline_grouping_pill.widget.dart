import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';

class TimelineGroupingPill extends ConsumerWidget {
  const TimelineGroupingPill({super.key, required this.isScrolling, required this.onChanged});

  final bool isScrolling;
  final ValueChanged<GroupAssetsBy> onChanged;

  static const _options = [GroupAssetsBy.year, GroupAssetsBy.month, GroupAssetsBy.day];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupBy = ref.watch(appConfigProvider.select((config) => config.timeline.groupAssetsBy));
    final normalized = groupBy == GroupAssetsBy.auto ? GroupAssetsBy.day : groupBy;
    final selected = _options.indexOf(normalized);
    final colorScheme = Theme.of(context).colorScheme;

    final background = colorScheme.surfaceContainerHigh.withValues(alpha: isScrolling ? 0.72 : 0.40);
    final selectedColor = colorScheme.surface.withValues(alpha: isScrolling ? 0.92 : 0.68);
    final borderColor = colorScheme.onSurface.withValues(alpha: isScrolling ? 0.16 : 0.10);

    return SizedBox(
      width: 190,
      height: 36,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(3),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _options.length;
                final safeSelected = selected < 0 ? 2 : selected;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      left: itemWidth * safeSelected,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isScrolling ? 0.20 : 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final option in _options)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: option == groupBy ? null : () => onChanged(option),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 180),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: option == groupBy ? FontWeight.w600 : FontWeight.w400,
                                    color: option == groupBy
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant.withValues(alpha: isScrolling ? 1 : 0.9),
                                  ),
                                  child: Text(switch (option) {
                                    GroupAssetsBy.year => '年',
                                    GroupAssetsBy.month => '月',
                                    _ => '日',
                                  }),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
