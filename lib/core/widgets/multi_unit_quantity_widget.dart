import 'package:flutter/material.dart';
import '../utils/unit_converter.dart';
import '../../features/medicines/domain/entities/medicines_entity.dart';

class MultiUnitQuantityWidget extends StatefulWidget {
  final int? qtyPerCarton;
  final int? qtyPerPack;
  final int? qtyPerStrip;
  final int medicineType;
  
  /// يتم استدعاء هذا الحدث عندما تتغير القيمة، ويرجع إجمالي الحبات مع التفاصيل
  final void Function(int totalPills, int cartons, int packs, int strips, int pills) onChanged;
  
  /// الكميات الابتدائية (اختياري)
  final int initialCartons;
  final int initialPacks;
  final int initialStrips;
  final int initialPills;

  const MultiUnitQuantityWidget({
    Key? key,
    this.qtyPerCarton,
    this.qtyPerPack,
    this.qtyPerStrip,
    this.medicineType = 1,
    required this.onChanged,
    this.initialCartons = 0,
    this.initialPacks = 0,
    this.initialStrips = 0,
    this.initialPills = 0,
  }) : super(key: key);

  @override
  State<MultiUnitQuantityWidget> createState() => _MultiUnitQuantityWidgetState();
}

class _MultiUnitQuantityWidgetState extends State<MultiUnitQuantityWidget> {
  late final TextEditingController _cartonCtrl;
  late final TextEditingController _packCtrl;
  late final TextEditingController _stripCtrl;
  late final TextEditingController _pillCtrl;

  @override
  void initState() {
    super.initState();
    _cartonCtrl = TextEditingController(text: widget.initialCartons > 0 ? widget.initialCartons.toString() : '');
    _packCtrl = TextEditingController(text: widget.initialPacks > 0 ? widget.initialPacks.toString() : '');
    _stripCtrl = TextEditingController(text: widget.initialStrips > 0 ? widget.initialStrips.toString() : '');
    _pillCtrl = TextEditingController(text: widget.initialPills > 0 ? widget.initialPills.toString() : '');

    _cartonCtrl.addListener(_notifyChange);
    _packCtrl.addListener(_notifyChange);
    _stripCtrl.addListener(_notifyChange);
    _pillCtrl.addListener(_notifyChange);
  }

  @override
  void dispose() {
    _cartonCtrl.dispose();
    _packCtrl.dispose();
    _stripCtrl.dispose();
    _pillCtrl.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final cartons = int.tryParse(_cartonCtrl.text) ?? 0;
    final packs = int.tryParse(_packCtrl.text) ?? 0;
    final strips = int.tryParse(_stripCtrl.text) ?? 0;
    final pills = int.tryParse(_pillCtrl.text) ?? 0;

    final totalPills = UnitConverter.toTotalPills(
      cartons: cartons,
      packs: packs,
      strips: strips,
      pills: pills,
      qtyPerCarton: widget.qtyPerCarton,
      qtyPerPack: widget.qtyPerPack,
      qtyPerStrip: widget.qtyPerStrip,
      medicineType: widget.medicineType,
    );
    widget.onChanged(totalPills, cartons, packs, strips, pills);
  }

  Widget _buildField(String label, TextEditingController controller, bool enabled) {
    if (!enabled) return const SizedBox.shrink();
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine which fields to show based on medicineType and packaging
    final bool hasCarton = (widget.qtyPerCarton ?? 0) > 0;
    final bool hasPack = (widget.qtyPerPack ?? 0) > 0;
    final bool hasStrip = (widget.qtyPerStrip ?? 0) > 0;

    if (widget.medicineType == 2) {
      // إبر وحقن: كرتون + باكت + حبة (إبرة/أمبولة)
      return Row(
        children: [
          _buildField('كرتون', _cartonCtrl, hasCarton || widget.qtyPerCarton == null),
          _buildField('باكت', _packCtrl, true),
          _buildField('حبة (إبرة)', _pillCtrl, true),
        ],
      );
    } else if (widget.medicineType == 3) {
      // أدوية العلب والمعلبات وزجاج ومغذيات: كرتون + علبة
      return Row(
        children: [
          _buildField('كرتون', _cartonCtrl, true),
          _buildField('علبة', _pillCtrl, true),
        ],
      );
    } else if (widget.medicineType == 4) {
      // فراشات وشرنجات: كرتون + حبة
      return Row(
        children: [
          _buildField('كرتون', _cartonCtrl, true),
          _buildField('حبة', _pillCtrl, true),
        ],
      );
    }

    // حبوب وأقراص (أو افتراضي): كرتون + باكت + شريط + حبة
    return Row(
      children: [
        _buildField('كرتون', _cartonCtrl, hasCarton),
        _buildField('باكت', _packCtrl, hasPack),
        _buildField('شريط', _stripCtrl, hasStrip),
        _buildField('حبة', _pillCtrl, true),
      ],
    );
  }
}
