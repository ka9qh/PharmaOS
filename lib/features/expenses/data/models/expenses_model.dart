import '../../../../core/database/app_database.dart';
import '../../domain/entities/expenses_entity.dart';

extension ExpenseRowMapper on ExpenseRow {
  ExpenseEntity toEntity({
    String? resolvedWorkerName,
    String? resolvedWalletName,
    String? resolvedRecorderName,
  }) =>
      ExpenseEntity(
        id: id,
        category: category,
        amount: amount,
        notes: notes,
        createdAt: createdAt,
        paymentMethod: paymentMethod,
        walletId: walletId,
        walletName: resolvedWalletName,
        workerId: workerId,
        workerName: resolvedWorkerName ?? (customWorkerName != null && customWorkerName!.trim().isNotEmpty ? customWorkerName!.trim() : null),
        customWorkerName: customWorkerName,
        recordedBy: recordedBy,
        recorderName: resolvedRecorderName,
      );
}
