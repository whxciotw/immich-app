import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/data/store.dart';
import 'package:immich_mobile/presentation/widgets/people/person_option_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/person_sliver_app_bar.dart';

@RoutePage()
class PersonPage extends ConsumerStatefulWidget {
  final Person person;

  const PersonPage({super.key, required this.person});

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  late Person _person;

  @override
  void initState() {
    super.initState();
    _person = widget.person;
  }

  Future<void> handleEditName(BuildContext context) async {
    final newName = await showNameEditModal(context, _person);

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _person = _person.copyWith(name: newName);
      });
    }
  }

  Future<void> handleEditBirthday(BuildContext context) async {
    final birthday = await showBirthdayEditModal(context, _person);

    if (birthday != null) {
      setState(() {
        _person = _person.copyWith(birthDate: birthday);
      });
    }
  }

  Future<void> handleSetFeaturePhoto() async {
    final updated = await context.pushRoute<Person>(PersonFeaturePhotoRoute(person: _person));
    if (updated != null && mounted) {
      setState(() => _person = updated);
    }
  }

  Future<void> handleMerge() async {
    final merged = await context.pushRoute<Person>(MergePeopleRoute(person: _person));
    if (merged != null && mounted) {
      setState(() => _person = merged);
    }
  }

  Future<void> handleToggleHidden() async {
    try {
      final updated = await ref.read(Store.people).updateHidden(_person.id, !_person.isHidden);
      if (!mounted) {
        return;
      }
      setState(() => _person = updated);
      ImmichToast.show(
        context: context,
        msg: updated.isHidden ? '人物已隐藏' : '人物已显示',
        toastType: ToastType.success,
      );
    } catch (error) {
      if (mounted) {
        ImmichToast.show(context: context, msg: '操作失败：$error', toastType: ToastType.error);
      }
    }
  }

  Future<void> showOptionSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: context.colorScheme.surface,
      isScrollControlled: false,
      builder: (sheetContext) {
        return PersonOptionSheet(
          onEditName: () async {
            await handleEditName(context);
            ContextHelper(sheetContext).pop();
          },
          onEditBirthday: () async {
            await handleEditBirthday(context);
            ContextHelper(sheetContext).pop();
          },
          onSetFeaturePhoto: () async {
            ContextHelper(sheetContext).pop();
            await handleSetFeaturePhoto();
          },
          onMerge: () async {
            ContextHelper(sheetContext).pop();
            await handleMerge();
          },
          onToggleHidden: () async {
            ContextHelper(sheetContext).pop();
            await handleToggleHidden();
          },
          birthdayExists: _person.birthDate != null,
          isHidden: _person.isHidden,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        timelineServiceProvider.overrideWith((ref) {
          final user = ref.watch(currentUserProvider);
          if (user == null) {
            throw Exception('User must be logged in to view person timeline');
          }

          final users = ref.watch(timelineUsersProvider).valueOrNull ?? [user.id];
          final timelineService = ref.watch(timelineFactoryProvider).person(users, _person.id);
          ref.onDispose(timelineService.dispose);
          return timelineService;
        }),
      ],
      child: Timeline(
        appBar: PersonSliverAppBar(
          person: _person,
          onNameTap: () => handleEditName(context),
          onBirthdayTap: () => handleEditBirthday(context),
          onShowOptions: () => showOptionSheet(context),
        ),
      ),
    );
  }
}
