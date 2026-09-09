import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/purchases_entity.dart';
import '../../../invoices/presentation/screens/invoice_details_screen.dart';

class PurchaseListTile extends StatelessWidget {
  final PurchaseEntity purchase;
  const PurchaseListTile({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    final hasRemaining = purchase.remainingAmount > 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasRemaining ? Colors.orange.shade200 : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceDetailsScreen(
                invoiceId: purchase.id,
                invoiceNumber: purchase.purchaseNumber,
                invoiceType: 'PURCHASE',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasRemaining ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: hasRemaining ? Colors.orange.shade800 : Colors.green.shade800,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          purchase.purchaseNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${purchase.supplierName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasRemaining ? Colors.orange.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hasRemaining ? Colors.orange.shade300 : Colors.green.shade300,
                            ),
                          ),
                          child: Text(
                            hasRemaining ? 'متبقي دين' : 'مسددة بالكامل',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasRemaining ? Colors.orange.shade900 : Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'الإجمالي: ${purchase.totalAmount.toStringAsFixed(0)} ر.ي',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'المدفوع: ${purchase.paidAmount.toStringAsFixed(0)} ر.ي',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                        ),
                        if (hasRemaining) ...[
                          const SizedBox(width: 12),
                          Text(
                            'المتبقي: ${purchase.remainingAmount.toStringAsFixed(0)} ر.ي',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(purchase.createdAt)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Row(
                          children: [
                            Text(
                              'عرض التفاصيل والسداد',
                              style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 10, color: Colors.blue.shade700),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
