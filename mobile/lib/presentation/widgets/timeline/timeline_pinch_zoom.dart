import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';

/// Pinch-to-zoom on the timeline grid.
///
/// - In manual layout mode it changes the number of columns (2-6) as before.
/// - In adaptive layout mode it cycles the grouping dimension instead:
///   pinch out (zoom in) -> day, pinch in (zoom out) -> year.
class TimelinePinchZoom extends ConsumerStatefulWidget {
  const TimelinePinchZoom({super.key, required this.onColumnCountWillChange, required this.child});

  final VoidCallback onColumnCountWillChange;

  final Widget child;

  @override
  ConsumerState<TimelinePinchZoom> createState() => _TimelinePinchZoomState();
}

class _TimelinePinchZoomState extends ConsumerState<TimelinePinchZoom> {
  int _perRow = 4;
  double _scaleFactor = 3.0;
  double _baseScaleFactor = 3.0;
  bool _groupSwitchConsumed = false;

  @override
  void initState() {
    super.initState();

    _perRow = ref.read(appConfigProvider.select((config) => config.timeline.tilesPerRow));
    _scaleFactor = 7.0 - _perRow;
    _baseScaleFactor = _scaleFactor;
  }

  GroupAssetsBy _nextGroup(GroupAssetsBy current, int direction) {
    // direction > 0: zoom in -> bigger tiles -> day
    // direction < 0: zoom out -> smaller tiles -> year
    const order = [GroupAssetsBy.year, GroupAssetsBy.month, GroupAssetsBy.day];
    final index = order.indexOf(current);
    if (index < 0) {
      return GroupAssetsBy.day;
    }
    final next = (index + direction).clamp(0, order.length - 1);
    return order[next];
  }

  Future<void> _applyGroup(GroupAssetsBy group) async {
    await ref.read(settingsProvider).write(.timelineGroupAssetsBy, group);
    ref.invalidate(appSettingsServiceProvider);
    ref.invalidate(timelineServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final auto = ref.watch(appConfigProvider.select((config) => config.timeline.autoTilesPerRow));
    final groupBy = ref.watch(appConfigProvider.select((config) => config.timeline.groupAssetsBy));

    return RawGestureDetector(
      gestures: {
        _CustomScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<_CustomScaleGestureRecognizer>(
          () => _CustomScaleGestureRecognizer(),
          (_CustomScaleGestureRecognizer scale) {
            scale.onStart = (details) {
              _baseScaleFactor = _scaleFactor;
              _groupSwitchConsumed = false;
            };

            scale.onUpdate = (details) {
              if (auto) {
                if (_groupSwitchConsumed) {
                  return;
                }
                final direction = details.scale > 1.15
                    ? 1
                    : details.scale < 0.87
                    ? -1
                    : 0;
                if (direction == 0) {
                  return;
                }
                final next = _nextGroup(groupBy, direction);
                if (next == groupBy) {
                  return;
                }
                _groupSwitchConsumed = true;
                widget.onColumnCountWillChange();
                unawaited(_applyGroup(next));
                return;
              }

              final newScaleFactor = math.max(math.min(5.0, _baseScaleFactor * details.scale), 1.0);
              final newPerRow = 7 - newScaleFactor.toInt();

              if (newPerRow != _perRow) {
                widget.onColumnCountWillChange();
                setState(() {
                  _scaleFactor = newScaleFactor;
                  _perRow = newPerRow;
                });

                unawaited(ref.read(settingsProvider).write(.timelineTilesPerRow, _perRow));
              }
            };
          },
        ),
      },
      child: widget.child,
    );
  }
}

/// accepts a gesture even though it should reject it (because child won)
class _CustomScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}
