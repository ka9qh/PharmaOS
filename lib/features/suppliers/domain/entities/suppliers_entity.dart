class SupplierEntity {
  final int id;
  final String name;
  final String? nameEn;
  final String? nameAr;
  final String? shortName;
  final String? representedCompanies;
  final String? contactInfo;
  final String? notes;

  const SupplierEntity({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameAr,
    this.shortName,
    this.representedCompanies,
    this.contactInfo,
    this.notes,
  });
}
