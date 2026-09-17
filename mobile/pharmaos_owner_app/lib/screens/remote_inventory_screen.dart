// شاشة المخزون الشامل وتعديل الأسعار الفوري عن بعد (Excel Grid View) - PharmaOS Owner App
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';

class RemoteInventoryScreen extends StatefulWidget {
  const RemoteInventoryScreen({super.key});

  @override
  State<RemoteInventoryScreen> createState() => _RemoteInventoryScreenState();
}

class _RemoteInventoryScreenState extends State<RemoteInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CloudMedicine> _medicines = [];
  List<CloudMedicine> _filteredMedicines = [];
  bool _isLoading = true;
  bool _isGridView = true; // نمط الجدول الشامل Excel vs بطاقات

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);
    final list = await OwnerApiService.fetchMedicinesCatalog();
    if (mounted) {
      setState(() {
        _medicines = list;
        _filteredMedicines = list;
        _isLoading = false;
      });
    }
  }

  void _filter(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredMedicines = _medicines);
      return;
    }
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredMedicines = _medicines.where((m) {
        return m.nameAr.toLowerCase().contains(q) ||
            (m.nameEn != null && m.nameEn!.toLowerCase().contains(q)) ||
            (m.barcode != null && m.barcode!.contains(q));
      }).toList();
    });
  }

  void _openPriceEditor(CloudMedicine med) {
    final sellController = TextEditingController(text: med.sellingPrice.toStringAsFixed(0));
    final purController = TextEditingController(text: med.purchasePrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: OwnerTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.price_change_rounded, color: OwnerTheme.accentGold, size: 22),
              const SizedBox(width: 8),
              const Text('تعديل سعر الدواء الفوري', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                med.nameAr,
                style: const TextStyle(color: OwnerTheme.primaryEmeraldLight, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (med.barcode != null) Text('الباركود: ${med.barcode}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              const SizedBox(height: 16),
              TextField(
                controller: sellController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: 'سعر البيع الجديد (ر.ي)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: purController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'سعر التكلفة / الشراء (ر.ي)'),
              ),
              const SizedBox(height: 12),
              Text(
                '⚡ يتزامن التعديل فورياً في أجزاء من الثانية مع أجهزة النظام المكتبي والكاشيرات مع إشعار مباشر.',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: OwnerTheme.primaryEmerald),
              onPressed: () async {
                final newSell = double.tryParse(sellController.text) ?? med.sellingPrice;
                final newPur = double.tryParse(purController.text) ?? med.purchasePrice;
                Navigator.pop(ctx);

                await OwnerApiService.updateMedicinePrice(
                  medicineId: med.id,
                  medicineName: med.nameAr,
                  newSellingPrice: newSell,
                  newPurchasePrice: newPur,
                );

                _loadMedicines();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: OwnerTheme.primaryEmerald,
                      content: Text('تم تعديل وتزامن سعر [${med.nameAr}] بنجاح إلى $newSell ر.ي'),
                    ),
                  );
                }
              },
              child: const Text('تطبيق التعديل الفوري'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddMedicineDialog() {
    final nameAr = TextEditingController();
    final nameEn = TextEditingController();
    final barcode = TextEditingController();
    final sell = TextEditingController();
    final pur = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: OwnerTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('إضافة دواء جديد للمخزون 💊', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameAr, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'الاسم بالعربي *')),
                const SizedBox(height: 8),
                TextField(controller: nameEn, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'الاسم بالإنجليزي')),
                const SizedBox(height: 8),
                TextField(controller: barcode, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'الباركود')),
                const SizedBox(height: 8),
                TextField(controller: sell, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'سعر البيع (ر.ي) *')),
                const SizedBox(height: 8),
                TextField(controller: pur, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'سعر الشراء (ر.ي)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: OwnerTheme.primaryEmerald),
              onPressed: () async {
                if (nameAr.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await OwnerApiService.addMedicine(
                  nameAr: nameAr.text.trim(),
                  nameEn: nameEn.text.trim().isNotEmpty ? nameEn.text.trim() : null,
                  barcode: barcode.text.trim().isNotEmpty ? barcode.text.trim() : null,
                  sellingPrice: double.tryParse(sell.text) ?? 0.0,
                  purchasePrice: double.tryParse(pur.text) ?? 0.0,
                );
                _loadMedicines();
              },
              child: const Text('حفظ وإرسال للنظام'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddSupplierDialog() {
    final name = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: OwnerTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('إضافة مورد جديد 🤝', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'اسم المورد / الشركة *')),
              const SizedBox(height: 8),
              TextField(controller: phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'هاتف المندوب')),
              const SizedBox(height: 8),
              TextField(controller: notes, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: OwnerTheme.primaryEmerald),
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await OwnerApiService.addSupplier(
                  name: name.text.trim(),
                  contactInfo: phone.text.trim(),
                  notes: notes.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة وتزامن المورد مع النظام المكتبي')),
                );
              },
              child: const Text('حفظ المورد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: OwnerTheme.darkBg,
        appBar: AppBar(
          backgroundColor: OwnerTheme.darkCard,
          elevation: 0,
          title: const Text('المخزون والأسعار الحية 📊'),
          actions: [
            IconButton(
              tooltip: _isGridView ? 'عرض البطاقات' : 'عرض جدول Excel',
              icon: Icon(_isGridView ? Icons.table_chart_rounded : Icons.grid_view_rounded),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            IconButton(
              tooltip: 'إضافة مورد',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: _openAddSupplierDialog,
            ),
            IconButton(
              tooltip: 'تحديث المخزون',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadMedicines,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: OwnerTheme.primaryEmerald,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('إضافة دواء جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: _openAddMedicineDialog,
        ),
        body: Column(
          children: [
            // شريط البحث المباشر
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم العربي، الإنجليزي أو الباركود...',
                  prefixIcon: const Icon(Icons.search_rounded, color: OwnerTheme.primaryEmeraldLight),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            _filter('');
                          },
                        )
                      : null,
                ),
                onChanged: _filter,
              ),
            ),

            // قائمة / جدول الأدوية
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: OwnerTheme.primaryEmeraldLight))
                  : _filteredMedicines.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'لا توجد نتائج مطابقة لبحثك'
                                      : 'لا توجد أدوية متزامنة سحابياً بعد\nاضغط على زر (مزامنة سحابية الآن) في بوابة تطبيق المدير على النظام المكتبي',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: OwnerTheme.primaryEmerald),
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('تحديث المخزون الآن'),
                                  onPressed: _loadMedicines,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isGridView
                          ? _buildExcelTableView()
                          : _buildCardListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExcelTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(OwnerTheme.darkCardElevated),
          dataRowColor: MaterialStateProperty.all(OwnerTheme.darkCard),
          border: TableBorder.all(color: OwnerTheme.surfaceBorder, width: 0.8),
          columns: const [
            DataColumn(label: Text('اسم الصنف', style: TextStyle(color: OwnerTheme.accentGoldLight, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('سعر البيع (ر.ي)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('سعر الشراء (ر.ي)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الكمية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الباركود', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('إجراء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
          rows: _filteredMedicines.map((m) {
            return DataRow(
              cells: [
                DataCell(
                  Text(m.nameAr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataCell(
                  Text('${m.sellingPrice.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold)),
                ),
                DataCell(
                  Text('${m.purchasePrice.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Colors.white70)),
                ),
                DataCell(
                  Text('${m.availableQuantity}', style: const TextStyle(color: Colors.white)),
                ),
                DataCell(
                  Text(m.barcode ?? '-', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: OwnerTheme.accentGold),
                    tooltip: 'تعديل السعر',
                    onPressed: () => _openPriceEditor(m),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCardListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredMedicines.length,
      itemBuilder: (context, index) {
        final m = _filteredMedicines[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: OwnerTheme.glassCardDecoration(),
          child: ListTile(
            title: Text(m.nameAr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('الباركود: ${m.barcode ?? 'لا يوجد'} | الكمية: ${m.availableQuantity}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${m.sellingPrice.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Color(0xFF34D399), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: OwnerTheme.accentGold, size: 20),
                  onPressed: () => _openPriceEditor(m),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
