import 'package:flutter/material.dart';
import '../../domain/entities/companies_entity.dart';

class CompanyListTile extends StatelessWidget {
  final CompanyEntity company;
  const CompanyListTile({super.key, required this.company});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.factory_outlined),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'رقم: ',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(company.name)),
        ],
      ),
    );
  }
}
