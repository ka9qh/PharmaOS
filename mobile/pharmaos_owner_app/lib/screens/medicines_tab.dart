// تبويب البحث في دليل الأدوية والمخزون - PharmaOS Owner App
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/owner_api_service.dart';

class MedicinesTab extends StatefulWidget {
  const MedicinesTab({super.key});

  @override
  State<MedicinesTab> createState() => _MedicinesTabState();
}

class _MedicinesTabState extends State<MedicinesTab> {
  final _searchController = TextEditingController();
  List<CloudMedicine> _medicines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchMedicines('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMedicines(String query) async {
    setState(() => _isLoading = true);
    final results = await OwnerApiService.searchMedicines(query);
    if (mounted) {
      setState(() {
        _medicines = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ar');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('دليل الأدوية والأسعار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          // شريط البحث
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم العربي أو العلمي أو الباركود...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.cyanAccent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _searchMedicines('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onSubmitted: _searchMedicines,
              onChanged: (val) {
                if (val.length >= 2 || val.isEmpty) {
                  _searchMedicines(val);
                }
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _medicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.medication_liquid_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 12),
                            const Text('لا توجد نتائج مطابقة لبحثك', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _medicines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final med = _medicines[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.medication_rounded, color: Color(0xFF6366F1), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.nameAr,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                      ),
                                      if (med.nameScientific != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          med.nameScientific!,
                                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                                        ),
                                      ],
                                      if (med.barcode != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'الباركود: ${med.barcode}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${currencyFormat.format(med.sellingPrice)} ر.ي',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'الشراء: ${currencyFormat.format(med.purchasePrice)} ر.ي',
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
