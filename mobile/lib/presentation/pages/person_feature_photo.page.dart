import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/data/store.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail.widget.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

@RoutePage()
class PersonFeaturePhotoPage extends HookConsumerWidget {
  const PersonFeaturePhotoPage({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsFuture = useMemoized(() => _loadAssets(ref), [person.id]);
    final assetsSnapshot = useFuture(assetsFuture);

    return Scaffold(
      appBar: AppBar(title: const Text('选择人物封面')),
      body: assetsSnapshot.hasError
          ? Center(child: Text('加载失败：${assetsSnapshot.error}'))
          : !assetsSnapshot.hasData
          ? const Center(child: CircularProgressIndicator())
          : assetsSnapshot.data!.isEmpty
          ? const Center(child: Text('这个人物暂时没有照片'))
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: assetsSnapshot.data!.length,
              itemBuilder: (context, index) {
                final asset = assetsSnapshot.data![index];
                return GestureDetector(
                  onTap: () => _select(context, ref, asset),
                  child: Thumbnail.fromAsset(asset: asset, fit: BoxFit.cover),
                );
              },
            ),
    );
  }

  Future<List<BaseAsset>> _loadAssets(WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return const [];
    }
    final users = ref.read(timelineUsersProvider).valueOrNull ?? [user.id];
    final query = ref.read(driftProvider).timelineRepository.person(users, person.id, GroupAssetsBy.day);
    return query.assetSource(0, 100);
  }

  Future<void> _select(BuildContext context, WidgetRef ref, BaseAsset asset) async {
    try {
      final updated = await ref.read(Store.people).updateFeaturePhoto(person.id, asset.id);
      if (context.mounted) {
        ImmichToast.show(context: context, msg: '人物封面已更新', toastType: ToastType.success);
        context.pop<Person>(updated);
      }
    } catch (error) {
      if (context.mounted) {
        ImmichToast.show(context: context, msg: '设置人物封面失败：$error', toastType: ToastType.error);
      }
    }
  }
}
