class NeededItemEntity {
  final int id;
  final String itemName;
  final String? notes;
  final String? customerName;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const NeededItemEntity({
    required this.id,
    required this.itemName,
    this.notes,
    this.customerName,
    this.isResolved = false,
    required this.createdAt,
    this.resolvedAt,
  });
}
