// شاشة النسخ الاحتياطي الثلاثي والتقارير المالية الحية عن بعد - PharmaOS Owner App
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/models.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';

class RemoteBackupReportsScreen extends StatefulWidget {
  const RemoteBackupReportsScreen({super.key});

  @override
  State<RemoteBackupReportsScreen> createState() => _RemoteBackupReportsScreenState();
}

class _RemoteBackupReportsScreenState extends State<RemoteBackupReportsScreen> {
  bool _isTriggeringBackup = false;
  List<CloudBackupRecord> _backups = [];
  List<CloudDayClosing> _closings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final bks = await OwnerApiService.fetchBackupsHistory();
    final cls = await OwnerApiService.fetchDayClosings();
    if (mounted) {
      setState(() {
        _backups = bks;
        _closings = cls;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRemoteBackup() async {
    setState(() => _isTriggeringBackup = true);

    final success = await OwnerApiService.triggerRemoteBackup();

    if (mounted) {
      setState(() => _isTriggeringBackup = false);
      if (success) {
        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: OwnerTheme.darkCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.cloud_done_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                  SizedBox(width: 8),
                  Text('تم إصدار أمر النسخ الاحتياطي 🛡️', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم إرسال الأمر للنظام المكتبي ويجري الآن إنشاء النسخ الثلاثية وتأمينها في:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  SizedBox(height: 10),
                  Text('1. الخزينة المحلية بجهاز الصيدلية', style: TextStyle(color: Colors.white, fontSize: 12)),
                  Text('2. الحساب السحابي المربوط بالنظام', style: TextStyle(color: Colors.white, fontSize: 12)),
                  Text('3. الخزينة السحابية الآمنة المشفرة (Telegram Vault)', style: TextStyle(color: OwnerTheme.accentGoldLight, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: OwnerTheme.primaryEmerald),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loadData();
                  },
                  child: const Text('حسناً'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال أمر النسخ، تحقق من اتصال الإنترنت')),
        );
      }
    }
  }

  void _showClosingDetails(CloudDayClosing c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: OwnerTheme.darkCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تقرير إغلاق الصندوق Z-Report (${DateFormat('yyyy-MM-dd').format(c.date)})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: OwnerTheme.surfaceBorder),
              const SizedBox(height: 10),
              _DetailRow(label: 'إجمالي المبيعات:', value: '${c.totalSales.toStringAsFixed(0)} ر.ي', color: const Color(0xFF34D399)),
              _DetailRow(label: 'إجمالي المرتجعات:', value: '${c.totalReturns.toStringAsFixed(0)} ر.ي', color: Colors.orangeAccent),
              _DetailRow(label: 'المصروفات التشغيلية:', value: '${c.totalExpenses.toStringAsFixed(0)} ر.ي', color: Colors.redAccent),
              _DetailRow(label: 'صافي الربح المحقق:', value: '${c.netProfit.toStringAsFixed(0)} ر.ي', color: OwnerTheme.accentGoldLight, isBold: true),
              _DetailRow(label: 'النقد الفعلي بالدرج (الكاش):', value: '${c.cashInDrawer.toStringAsFixed(0)} ر.ي', color: Colors.white),
            ],
          ),
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
          title: const Text('النسخ الاحتياطي والتقارير الحية 📑'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: OwnerTheme.primaryEmeraldLight))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقة طلب النسخ الاحتياطي الفوري
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: OwnerTheme.emeraldGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: OwnerTheme.primaryEmerald.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'النسخ الاحتياطي الثلاثي الفوري',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'إصدار أمر فوري للنظام لإنشاء وتأمين نسخة كاملة مشفرة لكافة الحسابات والمبيعات والمخزون ورفعها مباشرة.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _isTriggeringBackup ? null : _handleRemoteBackup,
                              child: _isTriggeringBackup
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('إصدار أمر النسخ الاحتياطي الآن ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // التقارير المالية وإغلاقات الصناديق الحية
                    const Text('تقارير الإغلاقات اليومية Z-Reports:', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (_closings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: OwnerTheme.glassCardDecoration(),
                        child: const Center(
                          child: Text('لا توجد تقارير إغلاق يومية محفوظة بعد', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ),
                      )
                    else
                      ..._closings.map((c) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: OwnerTheme.glassCardDecoration(),
                          child: ListTile(
                            onTap: () => _showClosingDetails(c),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: OwnerTheme.accentGold.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.assessment_rounded, color: OwnerTheme.accentGoldLight, size: 20),
                            ),
                            title: Text(
                              'إغلاق يوم ${DateFormat('yyyy-MM-dd').format(c.date)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text('المبيعات: ${c.totalSales.toStringAsFixed(0)} ر.ي | صافي الربح: ${c.netProfit.toStringAsFixed(0)} ر.ي', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    // سجل النسخ الاحتياطية
                    const Text('سجل النسخ الاحتياطية السحابية:', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ..._backups.map((b) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: OwnerTheme.glassCardDecoration(),
                        child: ListTile(
                          leading: const Icon(Icons.cloud_done_rounded, color: OwnerTheme.primaryEmeraldLight),
                          title: Text(b.fileName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('${b.summaryText} (${(b.fileSize / 1024 / 1024).toStringAsFixed(2)} MB)', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          trailing: Text(
                            DateFormat('MM/dd HH:mm').format(b.createdAt),
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _DetailRow({required this.label, required this.value, required this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
