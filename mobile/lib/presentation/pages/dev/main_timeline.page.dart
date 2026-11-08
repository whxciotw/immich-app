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
import 'package:immich_mobile/presentation/widgets/timeline/timeline_grouping_pill.widget.dart';
import 'package:immich_mobile/providers/feature_message.provider.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';

@RoutePage()
class MainTimelinePage extends ConsumerStatefulWidget {
  const MainTimelinePage({super.key});

  @override
  ConsumerState<MainTimelinePage> createState() => _MainTimelinePageState();
}

class _MainTimelinePageState extends ConsumerState<MainTimelinePage> {
  bool _isScrolling = false;
  Timer? _scrollTimer;

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

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
      _scrollTimer?.cancel();
      if (!_isScrolling) {
        setState(() => _isScrolling = true);
      }
      _scrollTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _isScrolling = false);
        }
      });
    }
    return false;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }

  Future<void> _setGroupBy(GroupAssetsBy value) async {
    await ref.read(settingsProvider).write(.timelineGroupAssetsBy, value);
    ref.invalidate(appSettingsServiceProvider);
    ref.invalidate(timelineServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final hasMemories = ref.watch(memoryLaneProvider.select((state) => state.value?.isNotEmpty ?? false));

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: Timeline(
            topSliverWidget: const SliverToBoxAdapter(child: MemoryLane()),
            topSliverWidgetHeight: hasMemories ? 200 : 0,
            bottomSliverWidget: const SliverToBoxAdapter(child: SizedBox(height: 72)),
            showStorageIndicator: true,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: Center(
            child: TimelineGroupingPill(
              isScrolling: _isScrolling,
              onChanged: (value) => unawaited(_setGroupBy(value)),
            ),
          ),
        ),
      ],
    );
  }
}
