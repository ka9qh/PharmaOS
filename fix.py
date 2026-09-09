import os
import re

def replace_in_file(path, pattern, replacement):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

replace_in_file(r'lib/features/closing/domain/services/daily_closing_service.dart', r'\[\'≈Ã„«·Ì «·„‘ —Ì« \'.*?\],', '')
replace_in_file(r'lib/features/closing/domain/services/daily_closing_service.dart', r'\'≈Ã„«·Ì «·„‘ —Ì« ,.*?\\n\'', '')

replace_in_file(r'lib/features/medicines/presentation/screens/medicines_screen.dart', r'class MedicinesScreen extends StatelessWidget', 'class MedicinesScreen extends ConsumerWidget')
replace_in_file(r'lib/features/medicines/presentation/screens/medicines_screen.dart', r'Widget build\(BuildContext context\)', 'Widget build(BuildContext context, WidgetRef ref)')

replace_in_file(r'lib/features/needed_items/presentation/screens/needed_items_screen.dart', r'textDirection: rtl', 'textDirection: TextDirection.rtl')

replace_in_file(r'lib/features/notifications/presentation/widgets/notifications_widget.dart', r'case AppNotificationType.general:\s+return Icons.notifications;', 'case AppNotificationType.neededItem:\n        return Icons.note_alt;\n      case AppNotificationType.general:\n        return Icons.notifications;')
replace_in_file(r'lib/features/notifications/presentation/widgets/notifications_widget.dart', r'case AppNotificationType.general:\s+return Colors.blue;', 'case AppNotificationType.neededItem:\n        return Colors.orange;\n      case AppNotificationType.general:\n        return Colors.blue;')

print("Done")
