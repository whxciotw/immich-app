import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/data/store.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/string_extensions.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';

enum _PeopleQuickAction { hideAll, hideUnnamed, showAll }

@RoutePage()
class PeopleCollectionPage extends ConsumerStatefulWidget {
  const PeopleCollectionPage({super.key});

  @override
  ConsumerState<PeopleCollectionPage> createState() => _PeopleCollectionPageState();
}

class _PeopleCollectionPageState extends ConsumerState<PeopleCollectionPage> {
  final FocusNode _formFocus = FocusNode();
  final Map<String, Person> _selected = {};
  String? _search;
  bool _showHidden = false;
  bool _selecting = false;
  bool _bulkBusy = false;

  @override
  void dispose() {
    _formFocus.dispose();
    super.dispose();
  }

  List<Person> _filter(List<Person> people) {
    if (_search == null) {
      return people;
    }
    final query = _search!.toLowerCase().removeDiacritics();
    return people
        .where((person) => person.name.toLowerCase().removeDiacritics().contains(query))
        .toList();
  }

  void _enterSelection(Person person) {
    _formFocus.unfocus();
    setState(() {
      _search = null;
      _selecting = true;
      _selected
        ..clear()
        ..[person.id] = person;
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelection(Person person) {
    setState(() {
      if (_selected.containsKey(person.id)) {
        _selected.remove(person.id);
      } else {
        _selected[person.id] = person;
      }
    });
  }

  Future<void> _selectAll() async {
    final people = await ref.read(Store.people.all(includeHidden: _showHidden).future);
    final filtered = _filter(people);
    if (!mounted) {
      return;
    }
    setState(() {
      _selected
        ..clear()
        ..addEntries(filtered.map((person) => MapEntry(person.id, person)));
    });
  }

  Future<bool> _confirm({required String title, required String message}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确定')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runBulk(List<Person> people, bool isHidden, String actionLabel) async {
    if (people.isEmpty || _bulkBusy) {
      return;
    }
    setState(() => _bulkBusy = true);
    try {
      final successCount = await ref.read(Store.people).updateHiddenBulk(people, isHidden);
      if (!mounted) {
        return;
      }
      final failedCount = people.length - successCount;
      if (successCount == 0) {
        ImmichToast.show(context: context, msg: '$actionLabel失败，请重试', toastType: ToastType.error);
      } else if (failedCount > 0) {
        ImmichToast.show(
          context: context,
          msg: '$actionLabel $successCount 个，失败 $failedCount 个',
          toastType: ToastType.info,
        );
      } else {
        ImmichToast.show(context: context, msg: '$actionLabel $successCount 个人物', toastType: ToastType.success);
      }
      setState(() {
        _bulkBusy = false;
        _selecting = false;
        _selected.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _bulkBusy = false);
        ImmichToast.show(context: context, msg: '$actionLabel失败：$error', toastType: ToastType.error);
      }
    }
  }

  Future<void> _runQuickAction(_PeopleQuickAction action) async {
    final all = await ref.read(Store.people.all(includeHidden: true).future);
    if (!mounted) {
      return;
    }
    final List<Person> targets;
    final String actionLabel;
    final String confirmTitle;
    final String confirmMessage;
    switch (action) {
      case _PeopleQuickAction.hideAll:
        targets = all.where((person) => !person.isHidden).toList();
        actionLabel = '隐藏';
        confirmTitle = '隐藏全部人物';
        confirmMessage = '将隐藏 ${targets.length} 个未隐藏的人物，确定继续吗？';
      case _PeopleQuickAction.hideUnnamed:
        targets = all.where((person) => !person.isHidden && person.name.trim().isEmpty).toList();
        actionLabel = '隐藏';
        confirmTitle = '隐藏未命名人物';
        confirmMessage = '将隐藏 ${targets.length} 个未命名的已显示人物，确定继续吗？';
      case _PeopleQuickAction.showAll:
        targets = all.where((person) => person.isHidden).toList();
        actionLabel = '显示';
        confirmTitle = '显示全部人物';
        confirmMessage = '将显示 ${targets.length} 个已隐藏的人物，确定继续吗？';
    }
    if (targets.isEmpty) {
      ImmichToast.show(context: context, msg: '没有需要处理的人物', toastType: ToastType.info);
      return;
    }
    final confirmed = await _confirm(title: confirmTitle, message: confirmMessage);
    if (!confirmed || !mounted) {
      return;
    }
    await _runBulk(targets, action != _PeopleQuickAction.showAll, actionLabel);
  }

  Future<void> _bulkSelected(bool isHidden) async {
    final targets = _selected.values.toList();
    if (targets.isEmpty || _bulkBusy) {
      return;
    }
    await _runBulk(targets, isHidden, isHidden ? '隐藏' : '显示');
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(Store.people.all(includeHidden: _showHidden));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final isPortrait = context.orientation == Orientation.portrait;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: _search == null && !_selecting,
            leading: _selecting
                ? IconButton(
                    tooltip: '退出选择',
                    icon: const Icon(Icons.close),
                    onPressed: _bulkBusy ? null : _exitSelection,
                  )
                : null,
            title: _selecting
                ? Text(_selected.isEmpty ? '选择人物' : '已选择 ${_selected.length} 项')
                : _search != null
                ? SearchField(
                    focusNode: _formFocus,
                    onTapOutside: (_) => _formFocus.unfocus(),
                    onChanged: (value) => setState(() => _search = value),
                    filled: true,
                    hintText: context.t.filter_people,
                    autofocus: true,
                  )
                : Text(context.t.people),
            actions: _selecting
                ? [
                    IconButton(
                      tooltip: '全选',
                      icon: const Icon(Icons.select_all),
                      onPressed: _bulkBusy ? null : _selectAll,
                    ),
                  ]
                : [
                    IconButton(
                      icon: Icon(_search != null ? Icons.close : Icons.search),
                      onPressed: () {
                        setState(() => _search = _search == null ? '' : null);
                      },
                    ),
                    IconButton(
                      tooltip: _showHidden ? '隐藏已隐藏的人物' : '显示已隐藏的人物',
                      icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() {
                        _showHidden = !_showHidden;
                        _selected.clear();
                        _selecting = false;
                      }),
                    ),
                    IconButton(
                      tooltip: '选择人物',
                      icon: const Icon(Icons.checklist),
                      onPressed: () => setState(() => _selecting = true),
                    ),
                    PopupMenuButton<_PeopleQuickAction>(
                      tooltip: '批量操作',
                      onSelected: (action) => unawaited(_runQuickAction(action)),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _PeopleQuickAction.hideUnnamed,
                          child: Text('隐藏未命名人物'),
                        ),
                        PopupMenuItem(
                          value: _PeopleQuickAction.hideAll,
                          child: Text('隐藏全部人物'),
                        ),
                        PopupMenuItem(
                          value: _PeopleQuickAction.showAll,
                          child: Text('显示全部人物'),
                        ),
                      ],
                    ),
                  ],
          ),
          body: SafeArea(
            child: people.when(
              data: (allPeople) {
                final filtered = _filter(allPeople);
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 6 : 3,
                    childAspectRatio: 0.85,
                    mainAxisSpacing: isPortrait && isTablet ? 36 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final person = filtered[index];
                    final isSelected = _selected.containsKey(person.id);

                    return Column(
                      key: ValueKey(person.id),
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_selecting) {
                              _toggleSelection(person);
                            } else {
                              unawaited(context.pushRoute(PersonRoute(person: person)));
                            }
                          },
                          onLongPress: () {
                            if (_selecting) {
                              _toggleSelection(person);
                            } else {
                              _enterSelection(person);
                            }
                          },
                          child: Material(
                            shape: CircleBorder(
                              side: _selecting && isSelected
                                  ? BorderSide(color: context.colorScheme.primary, width: 3)
                                  : BorderSide.none,
                            ),
                            elevation: 3,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  key: ValueKey(person.id),
                                  maxRadius: isTablet ? 100 / 2 : 96 / 2,
                                  backgroundImage: RemoteImageProvider(
                                    url: getFaceThumbnailUrl(person.id, updatedAt: person.updatedAt),
                                  ),
                                ),
                                if (person.isHidden)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: context.colorScheme.surfaceContainer,
                                      child: Icon(
                                        Icons.visibility_off,
                                        size: 16,
                                        color: context.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                if (_selecting)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? context.colorScheme.primary.withValues(alpha: 0.22)
                                              : Colors.black.withValues(alpha: 0.06),
                                        ),
                                        child: isSelected
                                            ? Center(
                                                child: Icon(
                                                  Icons.check_circle,
                                                  color: context.colorScheme.primary,
                                                  size: 30,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            if (_selecting) {
                              _toggleSelection(person);
                            } else {
                              showNameEditModal(context, person);
                            }
                          },
                          child: person.name.isEmpty
                              ? Text(
                                  context.t.add_a_name,
                                  style: context.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: context.colorScheme.primary,
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    person.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
              error: (error, stack) => const Text("error"),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
          bottomNavigationBar: _selecting
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _bulkBusy || _selected.isEmpty ? null : () => _bulkSelected(false),
                            icon: const Icon(Icons.visibility),
                            label: const Text('显示'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _bulkBusy || _selected.isEmpty ? null : () => _bulkSelected(true),
                            icon: const Icon(Icons.visibility_off),
                            label: const Text('隐藏'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
