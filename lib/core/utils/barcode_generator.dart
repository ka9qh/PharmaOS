// توليد SKU وقيمة باركود فريدة لكل دواء - راجع docs/WORKFLOW.md
// الصيغة: [رقم الشركة مبطّن بصفرين][رقم التصنيف مبطّن بصفرين][6 أرقام من الوقت الحالي]
// هذا يضمن عدم التكرار عمليًا دون استعلام مسبق لقاعدة البيانات، وينتج قيمة
// رقمية بحتة متوافقة تمامًا مع Code128 وأي قارئ باركود قياسي.

class BarcodeGenerator {
  BarcodeGenerator._();

  static String generate({int? companyId, int? categoryId}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final serial = (now % 1000000).toString().padLeft(6, '0');
    final companyPart = (companyId ?? 0).toString().padLeft(2, '0');
    final categoryPart = (categoryId ?? 0).toString().padLeft(2, '0');
    return '$companyPart$categoryPart$serial';
  }
}
