import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/data/store.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

@RoutePage()
class MergePeoplePage extends HookConsumerWidget {
  const MergePeoplePage({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(Store.people.all());
    final selected = useState<Set<String>>(<String>{});
    final merging = useState(false);

    void toggle(Person candidate) {
      final next = Set<String>.from(selected.value);
      if (!next.remove(candidate.id)) {
        if (next.length >= 5) {
          ImmichToast.show(context: context, msg: '一次最多选择 5 个人物', toastType: ToastType.info);
          return;
        }
        next.add(candidate.id);
      }
      selected.value = next;
    }

    Future<void> merge() async {
      if (selected.value.isEmpty || merging.value) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('合并人物'),
          content: Text('将把选中的 ${selected.value.length} 个人物合并到「${person.name}」，此操作不可撤销。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('合并')),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }

      merging.value = true;
      try {
        final merged = await ref.read(Store.people).mergePeople(person.id, selected.value.toList());
        if (!context.mounted) {
          return;
        }
        if (merged == null) {
          ImmichToast.show(context: context, msg: '合并失败，请重试', toastType: ToastType.error);
          return;
        }
        ImmichToast.show(context: context, msg: '已合并 ${selected.value.length + 1} 个人物', toastType: ToastType.success);
        Navigator.of(context).pop(merged);
      } catch (error) {
        if (context.mounted) {
          ImmichToast.show(context: context, msg: '合并失败：$error', toastType: ToastType.error);
        }
      } finally {
        if (context.mounted) {
          merging.value = false;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('合并人物'),
        actions: [
          TextButton(
            onPressed: selected.value.isEmpty || merging.value ? null : merge,
            child: merging.value
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('合并'),
          ),
        ],
      ),
      body: people.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载人物失败：$error')),
        data: (people) {
          final candidates = people.where((candidate) => candidate.id != person.id).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _PersonAvatar(person: person, radius: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '选择要合并到「${person.name}」的人物（最多 5 个）',
                        style: context.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '已选择 ${selected.value.length} 个',
                    style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.primary),
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    final isSelected = selected.value.contains(candidate.id);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => toggle(candidate),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              _PersonAvatar(person: candidate, radius: 40),
                              if (isSelected)
                                const Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.green,
                                    child: Icon(Icons.check, size: 16, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            candidate.name.isEmpty ? '未命名' : candidate.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: context.textTheme.bodyMedium,
                          ),
                        ],
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
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.person, required this.radius});

  final Person person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: RemoteImageProvider(url: getFaceThumbnailUrl(person.id, updatedAt: person.updatedAt)),
    );
  }
}
