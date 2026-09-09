import 'package:drift/native.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/core/di/service_locator.dart';
import 'package:pharmaos/features/medicines/domain/usecases/medicines_usecase.dart';
import 'package:pharmaos/features/medicines/domain/repositories/medicines_repository.dart';

void main() async {
  print('Setting up service locator...');
  await setupServiceLocator();
  print('Service locator ready. Fetching medicines...');
  try {
    final useCase = ListMedicinesUseCase(sl<MedicinesRepository>());
    final medicines = await useCase(searchQuery: null);
    print('Medicines fetched: ${medicines.length}');
  } catch (e, st) {
    print('Exception: $e');
    print('StackTrace: $st');
  }
}
