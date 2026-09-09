import 'package:flutter/material.dart';

class ReturnableLineTile extends StatelessWidget {
  final String medicineName;
  final int maxReturnable;
  final String subtitleExtra;
  final VoidCallback onTap;

  const ReturnableLineTile({
    super.key,
    required this.medicineName,
    required this.maxReturnable,
    required this.subtitleExtra,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canReturn = maxReturnable > 0;
    return ListTile(
      enabled: canReturn,
      leading: const Icon(Icons.undo_outlined),
      title: Text(medicineName),
      subtitle: Text(
        canReturn ? '$subtitleExtra â€¢ ط§ظ„ط­ط¯ ط§ظ„ظ…ط³ظ…ظˆط­ ظ„ظ„ط¥ط±ط¬ط§ط¹: $maxReturnable' : 'طھظ… ط¥ط±ط¬ط§ط¹ ظƒط§ظ…ظ„ ط§ظ„ظƒظ…ظٹط© ظ…ط³ط¨ظ‚ظ‹ط§',
      ),
      trailing: canReturn ? const Icon(Icons.chevron_left) : null,
      onTap: canReturn ? onTap : null,
    );
  }
}
