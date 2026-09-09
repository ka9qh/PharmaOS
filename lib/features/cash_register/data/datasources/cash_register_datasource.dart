import '../../../../core/database/app_database.dart';
import 'package:drift/drift.dart';

abstract class CashRegisterDataSource {
  Future<List<WalletRow>> getWallets();
  Future<int> addWallet(String name);
  Future<void> deleteWallet(int id);
  
  // Fetch transactions for cash (walletId = null) or a specific wallet
  Future<List<TransactionData>> getTransactions({int? walletId});
}

class TransactionData {
  final int id;
  final String description;
  final double amount;
  final DateTime date;
  final String type; // 'IN' or 'OUT'
  final String source;

  TransactionData({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.source,
  });
}

class CashRegisterDataSourceImpl implements CashRegisterDataSource {
  final AppDatabase db;

  CashRegisterDataSourceImpl(this.db);

  @override
  Future<List<WalletRow>> getWallets() async {
    return await db.select(db.wallets).get();
  }

  @override
  Future<int> addWallet(String name) async {
    return await db.into(db.wallets).insert(
          WalletsCompanion.insert(name: name),
        );
  }

  @override
  Future<void> deleteWallet(int id) async {
    await (db.delete(db.wallets)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<TransactionData>> getTransactions({int? walletId}) async {
    final transactions = <TransactionData>[];

    // Helper condition for walletId
    bool matchesWallet(int? wId, String method) {
      if (walletId == null) {
        return method == 'نقدي'; // Cash
      }
      return wId == walletId;
    }

    // 1. Sales (IN)
    final sales = await db.select(db.sales).get();
    for (var s in sales) {
      if (matchesWallet(s.walletId, s.paymentMethod) && s.paymentMethod != 'آجل') {
        transactions.add(TransactionData(
          id: s.id,
          description: 'مبيعات فاتورة #${s.invoiceNumber}',
          amount: s.totalAmount,
          date: s.createdAt,
          type: 'IN',
          source: 'sale',
        ));
      }
    }

    // 2. Customer Payments (IN)
    final custPayments = await db.select(db.customerPayments).get();
    for (var c in custPayments) {
      if (matchesWallet(c.walletId, c.paymentMethod)) {
        transactions.add(TransactionData(
          id: c.id,
          description: 'تسديد من عميل (ملاحظات: ${c.notes ?? ""})',
          amount: c.amount,
          date: c.createdAt,
          type: 'IN',
          source: 'customer_payment',
        ));
      }
    }

    // 3. Purchases (paidAmount) (OUT)
    final purchases = await db.select(db.purchases).get();
    for (var p in purchases) {
      if (p.paidAmount > 0 && matchesWallet(p.walletId, p.paymentMethod)) {
        transactions.add(TransactionData(
          id: p.id,
          description: 'مشتريات نقدية/محفظة #${p.purchaseNumber}',
          amount: p.paidAmount,
          date: p.createdAt,
          type: 'OUT',
          source: 'purchase',
        ));
      }
    }

    // 4. Vendor Payments (OUT)
    final vendPayments = await db.select(db.vendorPayments).get();
    for (var v in vendPayments) {
      if (matchesWallet(v.walletId, v.paymentMethod)) {
        transactions.add(TransactionData(
          id: v.id,
          description: 'تسديد لمورد (ملاحظات: ${v.notes ?? ""})',
          amount: v.amount,
          date: v.createdAt,
          type: 'OUT',
          source: 'vendor_payment',
        ));
      }
    }

    // 5. Expenses (OUT)
    final expenses = await db.select(db.expenses).get();
    for (var e in expenses) {
      if (matchesWallet(e.walletId, e.paymentMethod)) {
        transactions.add(TransactionData(
          id: e.id,
          description: 'مصروف: ${e.category} (${e.notes ?? ""})',
          amount: e.amount,
          date: e.createdAt,
          type: 'OUT',
          source: 'expense',
        ));
      }
    }

    // 6. Returns (IN/OUT)
    // - Sale Returns (refunds to customer) -> OUT
    // - Purchase Returns (refunds from supplier) -> IN
    final returnsList = await db.select(db.returns).get();
    for (var r in returnsList) {
      if (matchesWallet(r.walletId, r.paymentMethod)) {
        if (r.saleId != null) {
          // It's a sale return, we refunded the money to the customer
          transactions.add(TransactionData(
            id: r.id,
            description: 'استرداد نقدي لمرتجع مبيعات (سند #${r.id})',
            amount: r.totalAmount,
            date: r.createdAt,
            type: 'OUT',
            source: 'return',
          ));
        } else if (r.purchaseId != null) {
          // It's a purchase return, supplier refunded us
          transactions.add(TransactionData(
            id: r.id,
            description: 'استرداد نقدي لمرتجع مشتريات (سند #${r.id})',
            amount: r.totalAmount,
            date: r.createdAt,
            type: 'IN',
            source: 'return',
          ));
        }
      }
    }

    // Sort descending by date
    transactions.sort((a, b) => b.date.compareTo(a.date));

    return transactions;
  }
}
