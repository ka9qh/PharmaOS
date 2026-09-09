class CategoryEntity {
  final int id;
  final String name; // the primary/combined name
  final String? nameEn;
  final String? nameAr;
  const CategoryEntity({required this.id, required this.name, this.nameEn, this.nameAr});
}
