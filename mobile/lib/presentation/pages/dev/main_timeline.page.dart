import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/presentation/widgets/feature_message/feature_message_dialog.widget.dart';
import 'package:immich_mobile/presentation/widgets/memory/memory_lane.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/feature_message.provider.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';

@RoutePage()
class MainTimelinePage extends ConsumerStatefulWidget {
  const MainTimelinePage({super.key});

  @override
  ConsumerState<MainTimelinePage> createState() => _MainTimelinePageState();
}

class _MainTimelinePageState extends ConsumerState<MainTimelinePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final service = ref.read(featureMessageServiceProvider);
      if (!service.shouldShow()) {
        return;
      }

      await service.markSeen();
      if (!mounted) {
        return;
      }

      await showFeatureMessageDialog(context);
    });
  }

  Future<void> _setGroupBy(GroupAssetsBy value) async {
    await ref.read(settingsProvider).write(.timelineGroupAssetsBy, value);
    ref.invalidate(appSettingsServiceProvider);
    ref.invalidate(timelineServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final hasMemories = ref.watch(memoryLaneProvider.select((state) => state.value?.isNotEmpty ?? false));
    final groupBy = ref.watch(appConfigProvider.select((config) => config.timeline.groupAssetsBy));

    return Stack(
      children: [
        Timeline(
          topSliverWidget: const SliverToBoxAdapter(child: MemoryLane()),
          topSliverWidgetHeight: hasMemories ? 200 : 0,
          bottomSliverWidget: const SliverToBoxAdapter(child: SizedBox(height: 72)),
          showStorageIndicator: true,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 96,
          child: Center(
            child: SegmentedButton<GroupAssetsBy>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: GroupAssetsBy.year, label: Text('年')),
                ButtonSegment(value: GroupAssetsBy.month, label: Text('月')),
                ButtonSegment(value: GroupAssetsBy.day, label: Text('日')),
              ],
              selected: {groupBy},
              onSelectionChanged: (values) {
                if (values.isNotEmpty && values.first != groupBy) {
                  unawaited(_setGroupBy(values.first));
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
