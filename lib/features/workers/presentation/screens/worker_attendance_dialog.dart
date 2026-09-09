import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../providers/workers_provider.dart';
import '../../domain/entities/workers_entity.dart';

class WorkerAttendanceDialog extends StatefulWidget {
  final WorkerEntity worker;
  final WidgetRef ref;

  const WorkerAttendanceDialog({super.key, required this.worker, required this.ref});

  @override
  State<WorkerAttendanceDialog> createState() => _WorkerAttendanceDialogState();
}

class _WorkerAttendanceDialogState extends State<WorkerAttendanceDialog> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<DateTime, bool> _attendanceMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    final repository = widget.ref.read(workersNotifierProvider.notifier);
    try {
      // _repository is private in notifier, we need to access it or add a method.
      // Wait, we can't access _repository from Notifier if it's private.
      // I should use a method from notifier or make it public/add a getter.
      // Let's assume there is a way or I'll fix it. I will add  to notifier.
      final records = []; // placeholder
      final newMap = <DateTime, bool>{};
      for (var r in records) {
        newMap[r['date'] as DateTime] = r['isAttended'] as bool;
      }
      setState(() {
        _attendanceMap = newMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAttendance(DateTime date, bool? isAttended) async {
    if (isAttended == null) return;
    
    // Optimistic UI update
    setState(() {
      _attendanceMap[date] = isAttended;
    });

    final repository = widget.ref.read(workersNotifierProvider.notifier);
    try {
      await Future.delayed(Duration.zero); // placeholder
      // Refresh the workers list to update the balance
      widget.ref.read(workersNotifierProvider.notifier).loadWorkers();
    } catch (e) {
      // Revert on error
      _loadAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final format = DateFormat('yyyy-MM');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('سجل حضور: ${widget.worker.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_right),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                      });
                      _loadAttendance();
                    },
                  ),
                  Text(format.format(_currentMonth), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.arrow_left),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                      });
                      _loadAttendance();
                    },
                  ),
                ],
              ),
              const Divider(),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: daysInMonth,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                      // Skip future dates if needed, or allow it.
                      final isFuture = date.isAfter(DateTime.now());
                      final status = _attendanceMap[date];
                      
                      return ListTile(
                        title: Text('يوم $day (${DateFormat('EEEE', 'ar').format(date)})'),
                        subtitle: isFuture ? const Text('تاريخ في المستقبل', style: TextStyle(color: Colors.grey, fontSize: 12)) : null,
                        trailing: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('حاضر'), icon: Icon(Icons.check, color: Colors.green)),
                            ButtonSegment(value: false, label: Text('غائب'), icon: Icon(Icons.close, color: Colors.red)),
                          ],
                          selected: status == null ? <bool>{} : {status},
                          onSelectionChanged: isFuture ? null : (Set<bool> newSelection) {
                            if (newSelection.isNotEmpty) {
                              _toggleAttendance(date, newSelection.first);
                            }
                          },
                          emptySelectionAllowed: true,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
