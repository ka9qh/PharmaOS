import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../providers/ui_customization_provider.dart';

class CustomWidgetRenderer extends ConsumerWidget {
  final String location;
  
  const CustomWidgetRenderer({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgetsState = ref.watch(customWidgetsProvider);

    return widgetsState.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (allWidgets) {
        final locationWidgets = allWidgets.where((w) => w.location == location && w.isVisible).toList();
        if (locationWidgets.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: locationWidgets.map((widgetDef) {
            return _buildWidget(context, widgetDef);
          }).toList(),
        );
      },
    );
  }

  Widget _buildWidget(BuildContext context, dynamic widgetDef) {
    if (widgetDef.widgetType == 'button') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.star), // Can map iconName here later
        label: Text(widgetDef.label),
        onPressed: () => _handleAction(context, widgetDef),
        style: ElevatedButton.styleFrom(
          backgroundColor: widgetDef.colorHex != null ? _hexToColor(widgetDef.colorHex!) : null,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _handleAction(BuildContext context, dynamic widgetDef) async {
    final type = widgetDef.actionType;
    final data = widgetDef.actionData;
    
    if (type == 'open_url' && data != null) {
      final url = Uri.tryParse(data);
      if (url != null && await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرابط غير صالح')));
      }
    } else if (type == 'html_page' && data != null) {
      // عرض الصفحة المخصصة
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(widgetDef.label),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Markdown(data: data),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))
          ],
        )
      );
    }
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
