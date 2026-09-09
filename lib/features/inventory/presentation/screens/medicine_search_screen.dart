import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../widgets/receive_stock_dialog.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  final _searchController = TextEditingController();
  List<MedicineEntity> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await sl<MedicinesRepository>().getAll(searchQuery: query.trim());
    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _showReceiveDialog(int medicineId) async {
    await showDialog(
      context: context,
      builder: (context) => ReceiveStockDialog(initialMedicineId: medicineId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة دواء للمخزون'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'ابحث عن الدواء بالاسم أو الباركود...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                onChanged: _search,
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('ابحث عن الدواء لإضافته للمخزون'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final med = _results[index];
                        return ListTile(
                          title: Text(med.nameAr),
                          subtitle: Text(med.nameEn ?? ''),
                          trailing: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                          onTap: () => _showReceiveDialog(med.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
