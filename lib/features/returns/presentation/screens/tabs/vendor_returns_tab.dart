import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../providers/returns_provider.dart';

class VendorReturnsTab extends ConsumerStatefulWidget {
  const VendorReturnsTab({super.key});

  @override
  ConsumerState<VendorReturnsTab> createState() => _VendorReturnsTabState();
}

class _VendorReturnsTabState extends ConsumerState<VendorReturnsTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('سيتم إضافة مرتجعات الموردين قريباً'));
  }
}
