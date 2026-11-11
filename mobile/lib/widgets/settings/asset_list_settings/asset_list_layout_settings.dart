import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_ui/immich_ui.dart';

class LayoutSettings extends HookConsumerWidget {
  const LayoutSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tilesPerRow = useState(ref.watch(appConfigProvider.select((s) => s.timeline.tilesPerRow)));
    final autoTilesPerRow = useState(ref.watch(appConfigProvider.select((s) => s.timeline.autoTilesPerRow)));
    useValueChanged<int, void>(tilesPerRow.value, (_, _) {
      unawaited(ref.read(settingsProvider).write(.timelineTilesPerRow, tilesPerRow.value));
    });
    useValueChanged<bool, void>(autoTilesPerRow.value, (_, _) {
      unawaited(ref.read(settingsProvider).write(.timelineAutoTilesPerRow, autoTilesPerRow.value));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingGroupTitle(title: context.t.asset_list_layout_sub_title, icon: Icons.view_module_outlined),
        SettingsSwitchListTile(
          valueNotifier: autoTilesPerRow,
          title: '根据屏幕宽度自适应列数',
          subtitle: '年/月/日三种分组使用不同的基准列数，折叠屏/平板自动增加',
        ),
        if (!autoTilesPerRow.value)
          SettingsSliderListTile(
            valueNotifier: tilesPerRow,
            text: context.t.theme_setting_asset_list_tiles_per_row_title(count: tilesPerRow.value),
            label: "${tilesPerRow.value}",
            maxValue: 6,
            minValue: 2,
            noDivisons: 4,
            onChangeEnd: (value) {
              ref.invalidate(appSettingsServiceProvider);
            },
          ),
      ],
    );
  }
}
