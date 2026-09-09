import 'package:flutter/material.dart';
import '../../domain/entities/suppliers_entity.dart';

class SupplierListTile extends StatelessWidget {
  final SupplierEntity supplier;
  const SupplierListTile({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.local_shipping_outlined),
      title: Text(supplier.name),
      subtitle: supplier.contactInfo != null ? Text(supplier.contactInfo!) : null,
    );
  }
}
