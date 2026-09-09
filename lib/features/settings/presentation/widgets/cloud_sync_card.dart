// بطاقة إدارة المزامنة السحابية وقاعدة بيانات Supabase - PharmaOS
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/cloud_sync_service.dart';

class CloudSyncCard extends StatefulWidget {
  const CloudSyncCard({super.key});

  @override
  State<CloudSyncCard> createState() => _CloudSyncCardState();
}

class _CloudSyncCardState extends State<CloudSyncCard> {
  bool _isSyncEnabled = true;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String _serverStatus = 'جاهز للمزامنة';

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    final enabled = await CloudSyncService.isCloudSyncEnabled();
    final lastTime = await CloudSyncService.getLastSyncTime();
    if (mounted) {
      setState(() {
        _isSyncEnabled = enabled;
        _lastSyncTime = lastTime;
      });
    }
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
      _serverStatus = 'جاري المزامنة مع سيرفر Supabase...';
    });

    final result = await CloudSyncService.triggerFullSync();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _serverStatus = result.isSuccess ? 'تمت المزامنة بنجاح' : 'تعذر الاتصال (النظام يعمل محلياً)';
        _lastSyncTime = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'اكتملت المزامنة'),
          backgroundColor: result.isSuccess ? Colors.teal : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueGrey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_sync_rounded, color: Colors.indigo, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'المزامنة السحابية وتعدد الفروع (Supabase Cloud Sync)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(width: 8),
                          Chip(
                            label: Text('متصل بالسيرفر', style: TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: Colors.teal,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lastSyncTime != null
                            ? 'آخر مزامنة ناجحة: ${DateFormat("yyyy-MM-dd HH:mm").format(_lastSyncTime!)}'
                            : 'حالة السيرفر: $_serverStatus',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isSyncEnabled,
                  activeColor: Colors.teal,
                  onChanged: (val) async {
                    setState(() => _isSyncEnabled = val);
                    await CloudSyncService.setCloudSyncEnabled(val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الرابط السحابي: ${CloudSyncService.defaultSupabaseUrl}',
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSyncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('مزامنة سحابية الآن'),
                  onPressed: (_isSyncing || !_isSyncEnabled) ? null : _performSync,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
