# الوحدات الرئيسية وعلاقتها ببعضها - PharmaOS

Inventory ⇄ Sales/POS ⇄ Accounting ⇄ Reports
     ↓             ↓            ↓
  Barcode      Returns      Day Closing
     ↓
 Stock Alerts

Users/Roles تتحكم في كل الوحدات أعلاه عبر RoleGuard.
Licensing يعمل بشكل مستقل تمامًا كبوابة دخول أولى للنظام قبل أي وحدة أخرى.
Audit Logs يراقب كل الوحدات دون استثناء.
