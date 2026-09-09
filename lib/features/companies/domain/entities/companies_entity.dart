class CompanyEntity {
  final int id;
  final String name; // Combined name
  final String? nameEn;
  final String? nameAr;
  final String? countryAr;
  final String? countryEn;
  final int medicinesCount;
  
  const CompanyEntity({
    required this.id, 
    required this.name, 
    this.nameEn,
    this.nameAr,
    this.countryAr,
    this.countryEn,
    this.medicinesCount = 0,
  });
}
