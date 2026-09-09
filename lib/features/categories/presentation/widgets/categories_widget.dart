import 'package:flutter/material.dart';
import '../../domain/entities/categories_entity.dart';

class CategoryListTile extends StatelessWidget {
  final CategoryEntity category;
  const CategoryListTile({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.category_outlined),
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
          Expanded(child: Text(category.name)),
        ],
      ),
    );
  }
}
