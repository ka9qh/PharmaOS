class WorkerEntity {
  final int? id;
  final String name;
  final String role;
  final String phone;
  final double salary;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkerEntity({
    this.id,
    required this.name,
    this.role = '',
    this.phone = '',
    this.salary = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });
}
