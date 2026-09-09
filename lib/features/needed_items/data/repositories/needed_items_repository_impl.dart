import '../../domain/entities/needed_item_entity.dart';
import '../../domain/repositories/needed_items_repository.dart';
import '../datasources/needed_items_datasource.dart';
import '../../../../core/security/audit_logger.dart';

class NeededItemsRepositoryImpl implements NeededItemsRepository {
  final NeededItemsDataSource dataSource;
  final AuditLogger auditLogger;

  NeededItemsRepositoryImpl({required this.dataSource, required this.auditLogger});

  @override
  Future<List<NeededItemEntity>> getAll({bool includeResolved = false}) =>
      dataSource.getAll(includeResolved: includeResolved);

  @override
  Future<NeededItemEntity> create({required String itemName, String? notes, String? customerName}) async {
    final item = await dataSource.create(itemName: itemName, notes: notes, customerName: customerName);
    await auditLogger.log(
      actionType: 'NEEDED_ITEM_CREATED',
      tableName: 'needed_items',
      recordId: item.id.toString(),
      newValue: 'item=$itemName, customer=${customerName ?? "غير محدد"}',
    );
    return item;
  }

  @override
  Future<void> resolve(int id) async {
    await dataSource.resolve(id);
    await auditLogger.log(
      actionType: 'NEEDED_ITEM_RESOLVED',
      tableName: 'needed_items',
      recordId: id.toString(),
    );
  }

  @override
  Future<void> delete(int id) async {
    await dataSource.delete(id);
    await auditLogger.log(
      actionType: 'NEEDED_ITEM_DELETED',
      tableName: 'needed_items',
      recordId: id.toString(),
    );
  }
}
