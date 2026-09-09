class ExpenseEntity {
  final int id;
  final String category;
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final String paymentMethod;
  final int? walletId;
  final String? walletName;
  final int? workerId;
  final String? workerName; // can be customWorkerName or joined from Workers table
  final String? customWorkerName;
  final int? recordedBy;
  final String? recorderName;

  const ExpenseEntity({
    required this.id,
    required this.category,
    required this.amount,
    this.notes,
    required this.createdAt,
    this.paymentMethod = 'نقدي',
    this.walletId,
    this.walletName,
    this.workerId,
    this.workerName,
    this.customWorkerName,
    this.recordedBy,
    this.recorderName,
  });
}
