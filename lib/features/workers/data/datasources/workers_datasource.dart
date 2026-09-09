import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

import '../../domain/entities/workers_entity.dart';

import '../../domain/entities/workers_entity.dart';



abstract class WorkersDataSource {

  Future<List<WorkerEntity>> getAllWorkers();

  Future<WorkerEntity> createWorker({

    required String name,

    String? phone,

    required double salary,

    double? dailyWithdrawalLimit,

    required bool allowanceIsDeducted,

    String? notes,

  });

  Future<void> updateWorker({

    required int id,

    required String name,

    String? phone,

    required double salary,

    double? dailyWithdrawalLimit,

    required bool allowanceIsDeducted,

    String? notes,

  });

  Future<void> archiveWorker(int id);

}



class WorkersDataSourceImpl implements WorkersDataSource {

  final AppDatabase _db;

  WorkersDataSourceImpl(this._db);



  WorkerEntity _mapRow(WorkerRow row, double totalWithdrawn) {

    return WorkerEntity(

      id: row.id,

      name: row.name,

      phone: row.phone ?? "",

      salary: row.salary,
// 
//       dailyWithdrawalLimit: row.dailyWithdrawalLimit,

      

//       notes: row.notes,

      isActive: row.isActive,

      createdAt: row.createdAt,
      updatedAt: row.createdAt,

//       totalWithdrawn: totalWithdrawn,

//       remainingBalance: row.salary - totalWithdrawn,

    );

  }



  @override

  Future<List<WorkerEntity>> getAllWorkers() async {

    final workers = await (_db.select(_db.workers)..where((tbl) => tbl.isActive.equals(true))).get();

    

    // حساب المسحوبات لكل موظف في الشهر الحالي

    final now = DateTime.now();

    final startOfMonth = DateTime(now.year, now.month, 1);

    

    final result = <WorkerEntity>[];

    for (var w in workers) {

      final expensesQuery = _db.select(_db.expenses)..where((tbl) => tbl.workerId.equals(w.id) & tbl.createdAt.isBiggerOrEqualValue(startOfMonth));

      final expenses = await expensesQuery.get();

      

      // إذا كانت allowanceIsDeducted == false، هل نخصم المسحوبات؟ 

      // حسب الطلب: "المصروف يُخصم منه إذا كان راتب بس" أي إذا كان allowanceIsDeducted == true فإننا نحسب المسحوبات.

      // إذا كانت false، فربما المصروفات التي يأخذها تعتبر بدل إضافي لا تُخصم من الراتب. لكن في كل الأحوال المسحوبات المخصومة هي فقط عندما allowanceIsDeducted == true؟

      // الأفضل: نحسب إجمالي ما استلمه كـ totalWithdrawn، أما الرصيد المتبقي (remainingBalance) فيكون: 

      // إذا allowanceIsDeducted == true -> الراتب - إجمالي المسحوبات.

      // إذا allowanceIsDeducted == false -> الراتب - إجمالي المسحوبات (ولكن يمكن أن يكون قد أخذ المصروف الإضافي الذي لا يحسب من الراتب).

      // من الأسهل: نجمع فقط المصروفات التي يجب أن تُخصم من الراتب، أو نعتبر أن جميع المسحوبات تُخصم إذا allowanceIsDeducted == true، أما إذا كانت false فلا تُخصم.

      // لتفادي التعقيد: المستخدم طلب: "أقدر أحدد للموظف راتب مع مصروف يومي أو راتب بس والمصروف ينخصم منه".

      // سنجمع جميع المصروفات في totalWithdrawn، لكن حساب المتبقي يعتمد على القاعدة: إذا كان allowanceIsDeducted == false، فإن الرصيد المتبقي لا يقل بسبب المصروفات اليومية. 

      // لنفترض أن جميع المبالغ المسجلة كمصروفات تُحسب في totalWithdrawn.

      double total = 0;

      for (var e in expenses) {

        total += e.amount;

      }

      

      result.add(_mapRow(w, total));

    }

    

    return result;

  }



  @override

  Future<WorkerEntity> createWorker({

    required String name,

    String? phone,

    required double salary,

    double? dailyWithdrawalLimit,

    required bool allowanceIsDeducted,

    String? notes,

  }) async {

    final row = await _db.into(_db.workers).insertReturning(

      WorkersCompanion.insert(

        name: name,

        phone: Value(phone),

        salary: Value(salary),
// 
        dailyWithdrawalLimit: Value(dailyWithdrawalLimit),

        allowanceIsDeducted: Value(allowanceIsDeducted),

        notes: Value(notes),

      ),

    );

    return _mapRow(row, 0);

  }



  @override

  Future<void> updateWorker({

    required int id,

    required String name,

    String? phone,

    required double salary,

    double? dailyWithdrawalLimit,

    required bool allowanceIsDeducted,

    String? notes,

  }) async {

    await (_db.update(_db.workers)..where((tbl) => tbl.id.equals(id))).write(

      WorkersCompanion(

        name: Value(name),

        phone: Value(phone),

        salary: Value(salary),
// 
        dailyWithdrawalLimit: Value(dailyWithdrawalLimit),

        allowanceIsDeducted: Value(allowanceIsDeducted),

        notes: Value(notes),

      ),

    );

  }



  @override

  Future<void> archiveWorker(int id) async {

    await (_db.update(_db.workers)..where((tbl) => tbl.id.equals(id))).write(

      const WorkersCompanion(isActive: Value(false)),

    );

  }

}

