# تصميم قاعدة البيانات - PharmaOS
(تصميم منطقي فقط - بدون SQL أو Drift فعلي، يُنفَّذ لاحقًا في مرحلة Inventory)

## مبدأ التصميم
كل جدول يحتوي على حقل `pharmacy_id` منذ البداية (حتى لو لم يُستخدم فعليًا الآن)
لأن النظام سيُباع كمنتج لعدة صيدليات لاحقًا، وهذا يجنبنا إعادة هيكلة مؤلمة مستقبلاً.

## الجداول الرئيسية

### medicines (الأدوية)
id, pharmacy_id, name_ar, name_scientific, category_id, company_id,
sku, barcode, unit, purchase_price, selling_price,
reorder_level (حد التنبيه), created_at, updated_at, is_active

### batches (دفعات الأدوية - لتتبع الصلاحية والكمية بدقة)
id, medicine_id, batch_number, expiry_date, quantity, purchase_price, received_at

### categories / companies / suppliers / customers
حقول أساسية: id, pharmacy_id, name, contact_info, notes

### sales (الفواتير)
id, pharmacy_id, invoice_number, cashier_id, total_amount, discount,
payment_method, status (completed/returned/partially_returned), created_at, closed_day_id

### sale_items (بنود الفاتورة)
id, sale_id, medicine_id, batch_id, quantity, unit_price, subtotal

### returns (المرتجعات)
id, sale_id (مرتجع عميل) أو purchase_id (مرتجع مورد), items, reason, processed_by, created_at

### purchases (فواتير الشراء من الموردين)
id, pharmacy_id, purchase_number, supplier_invoice_ref (اختياري), supplier_id,
total_amount, paid_amount, created_at
**تحديث Phase 4a**: لا يوجد عمود remaining_amount أو status مخزَّن - المتبقي
يُحسب دائمًا (total_amount - paid_amount - أي تسديدات لاحقة من vendor_payments)
لحظيًا بدلاً من تخزينه، لتفادي أي تضارب بيانات لاحقًا.

### purchase_items (بنود فاتورة الشراء)
id, purchase_id, medicine_id, batch_id (كل بند ينشئ دفعة جديدة عند الحفظ), quantity, unit_cost, subtotal

### expenses (المصاريف)
id, pharmacy_id, category (كهرباء/رواتب/أخرى), amount, notes, recorded_by, created_at

### vendor_payments (تسديدات للتجار)
id, pharmacy_id, supplier_id, amount, notes, recorded_by, created_at

### users (المستخدمون)
id, pharmacy_id, full_name, username, password_hash (bcrypt), role_id, is_active

### roles / permissions
نظام صلاحيات مرن: Owner, Manager, Accountant, Cashier, Inventory Clerk
كل دور له مجموعة صلاحيات محددة (انظر SECURITY_GUIDELINES.md)

### audit_log (سجل التدقيق) - غير قابل للتعديل أو الحذف نهائيًا
id, pharmacy_id, user_id, action_type, table_name, record_id,
old_value (JSON), new_value (JSON), timestamp

### day_closings (تقارير إغلاق النوبة) - Snapshot لكل إصدار تقرير
id, pharmacy_id, date (اليوم التقويمي - للعرض فقط), period_start (بداية الفترة
المُغطاة، أي وقت آخر تقرير سابق)، total_sales, total_returns, total_expenses,
total_vendor_payments, cost_of_goods_sold, net_profit, cash_in_drawer, closed_by,
report_pdf_path, report_excel_path, backup_path, created_at (نهاية الفترة فعليًا)

**تصحيح مهم**: لا يوجد قيد تفرد على date. يمكن إصدار عدة تقارير في نفس اليوم
التقويمي (نوبات عمل متعددة لصيدليات 24 ساعة)، وهذا الجدول **لا يمثّل قفلًا**
لأي عملية - راجع docs/WORKFLOW.md للتفاصيل الكاملة وسبب هذا القرار.

### licenses (بيانات الترخيص - محلية فقط، راجع docs/LICENSING_STRATEGY.md)
id, pharmacy_id, hardware_id, license_key, pharmacy_name, activated_at, expires_at (اختياري - null = دائم)

## العلاقات الأساسية
- medicine → batches (1 إلى متعدد)
- sale → sale_items → medicine/batch
- purchase → supplier
- expense/vendor_payment → day_closing (عبر التاريخ)

## قاعدة صارمة لسلامة البيانات
لا يُحذف أي سجل بيع أو شراء نهائيًا من القاعدة. أي "حذف" هو في الحقيقة
قيد عكسي (Reversal Entry) أو تغيير status، مع تسجيل إلزامي في audit_log.
