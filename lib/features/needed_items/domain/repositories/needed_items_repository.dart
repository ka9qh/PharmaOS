import '../entities/needed_item_entity.dart';

abstract class NeededItemsRepository {
  Future<List<NeededItemEntity>> getAll({bool includeResolved = false});
  Future<NeededItemEntity> create({required String itemName, String? notes, String? customerName});
  Future<void> resolve(int id);
  Future<void> delete(int id);
}
