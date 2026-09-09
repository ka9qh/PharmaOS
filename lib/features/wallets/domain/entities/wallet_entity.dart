class WalletEntity {
  final int id;
  final String name;
  final DateTime createdAt;

  const WalletEntity({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory WalletEntity.fromJson(Map<String, dynamic> json) => WalletEntity(
        id: json['id'] as int,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };
}
