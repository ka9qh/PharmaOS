class PayrollEntity {
  final int id;
  final int workerId;
  final String workerName;
  final int month;
  final int year;
  final double baseSalary;
  final double totalAllowances;
  final double totalDeductions;
  final double totalAdvancesDeducted;
  final double daysWorked;
  final double daysAbsent;
  final double netSalary;
  final String paymentMethod;
  final String status; // pending, paid
  final int? paidBy;
  final DateTime? paidAt;
  final String? notes;
  final DateTime createdAt;

  PayrollEntity({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.month,
    required this.year,
    required this.baseSalary,
    required this.totalAllowances,
    required this.totalDeductions,
    required this.totalAdvancesDeducted,
    required this.daysWorked,
    required this.daysAbsent,
    required this.netSalary,
    required this.paymentMethod,
    required this.status,
    this.paidBy,
    this.paidAt,
    this.notes,
    required this.createdAt,
  });

  bool get isPaid => status == 'paid';

  String get monthName {
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
                     'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return months[month - 1];
  }
}

class WorkerAdvanceEntity {
  final int id;
  final int workerId;
  final String workerName;
  final double amount;
  final String? reason;
  final bool isFullyDeducted;
  final double remainingAmount;
  final String paymentMethod;
  final int? approvedBy;
  final String? notes;
  final DateTime createdAt;

  WorkerAdvanceEntity({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.amount,
    this.reason,
    required this.isFullyDeducted,
    required this.remainingAmount,
    required this.paymentMethod,
    this.approvedBy,
    this.notes,
    required this.createdAt,
  });
}
