import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/data/server/api_repository.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:openapi/api.dart';

final personApiRepositoryProvider = Provider((ref) => PersonApiRepository(ref.watch(apiServiceProvider).peopleApi));

class PersonApiRepository extends ApiRepository {
  final PeopleApi _api;

  const PersonApiRepository(this._api);

  Future<Person> update(
    String id, {
    String? name,
    DateTime? birthday,
    bool? isHidden,
    String? featureFaceAssetId,
  }) async {
    final birthdayUtc = birthday == null ? null : DateTime.utc(birthday.year, birthday.month, birthday.day);
    final dto = PersonUpdateDto(
      name: name == null ? const Optional.absent() : Optional.present(name),
      birthDate: birthdayUtc == null ? const Optional.absent() : Optional.present(birthdayUtc),
      isHidden: isHidden == null ? const Optional.absent() : Optional.present(isHidden),
      featureFaceAssetId: featureFaceAssetId == null
          ? const Optional.absent()
          : Optional.present(featureFaceAssetId),
    );
    final response = await checkNull(_api.updatePerson(id, dto));
    return _toPerson(response);
  }

  Future<Person?> mergePeople(String targetId, List<String> otherIds) async {
    final results = await checkNull(_api.mergePeople(MergePersonDto(ids: [targetId, ...otherIds])));
    if (!results.any((result) => result.success)) {
      return null;
    }
    final response = await _api.getPerson(targetId);
    return response == null ? null : _toPerson(response);
  }

  static Person _toPerson(PersonResponseDto dto) => .new(
    birthDate: dto.birthDate,
    id: dto.id,
    name: dto.name,
    updatedAt: dto.updatedAt.orElse(null),
    isHidden: dto.isHidden,
  );
}
