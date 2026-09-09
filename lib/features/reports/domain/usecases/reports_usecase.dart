import '../entities/reports_entity.dart';
import '../repositories/reports_repository.dart';

class PreviewCurrentPeriodUseCase {
  final ReportsRepository _repo;
  const PreviewCurrentPeriodUseCase(this._repo);
  Future<DayClosingSummary> call() => _repo.previewCurrentPeriod();
}

class GetLastClosingTimeUseCase {
  final ReportsRepository _repo;
  const GetLastClosingTimeUseCase(this._repo);
  Future<DateTime?> call() => _repo.getLastClosingTime();
}

class CloseCurrentPeriodUseCase {
  final ReportsRepository _repo;
  const CloseCurrentPeriodUseCase(this._repo);
  Future<DayClosingResult> call({int? closedByUserId}) =>
      _repo.closeCurrentPeriod(closedByUserId: closedByUserId);
}

class ListRecentClosingsUseCase {
  final ReportsRepository _repo;
  const ListRecentClosingsUseCase(this._repo);
  Future<List<DayClosingRecordEntity>> call({int limit = 30}) => _repo.listRecent(limit: limit);
}

class DeleteClosingRecordUseCase {
  final ReportsRepository _repo;
  const DeleteClosingRecordUseCase(this._repo);
  Future<void> call(int id, {int? deletedBy}) => _repo.deleteClosingRecord(id, deletedBy: deletedBy);
}
