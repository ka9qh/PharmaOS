import 'package:flutter/material.dart';

class SearchableDropdownWithActions<T> extends StatefulWidget {
  final String label;
  final List<T> items;
  final String Function(T) itemAsString;
  final T? value;
  final void Function(T?) onChanged;
  final void Function(String)? onAddOther;
  final void Function(T)? onEdit;
  final void Function(T)? onDelete;
  final String? errorText;

  const SearchableDropdownWithActions({
    super.key,
    required this.label,
    required this.items,
    required this.itemAsString,
    required this.value,
    required this.onChanged,
    this.onAddOther,
    this.onEdit,
    this.onDelete,
    this.errorText,
  });

  @override
  State<SearchableDropdownWithActions<T>> createState() => _SearchableDropdownWithActionsState<T>();
}

class _SearchableDropdownWithActionsState<T> extends State<SearchableDropdownWithActions<T>> {
  Future<void> _showSearchDialog() async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => _SearchDialog<T>(
        label: widget.label,
        items: widget.items,
        itemAsString: widget.itemAsString,
        onAddOther: widget.onAddOther != null ? (val) => Navigator.pop(context, {'action': 'add', 'value': val}) : null,
        onEdit: widget.onEdit != null ? (item) => Navigator.pop(context, {'action': 'edit', 'item': item}) : null,
        onDelete: widget.onDelete != null ? (item) => Navigator.pop(context, {'action': 'delete', 'item': item}) : null,
      ),
    );

    if (result != null) {
      if (result is T) {
        widget.onChanged(result);
      } else if (result is Map) {
        if (result['action'] == 'add') {
          widget.onAddOther?.call(result['value']);
        } else if (result['action'] == 'edit') {
          widget.onEdit?.call(result['item']);
        } else if (result['action'] == 'delete') {
          widget.onDelete?.call(result['item']);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _showSearchDialog,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          errorText: widget.errorText,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          widget.value != null ? widget.itemAsString(widget.value as T) : 'اختر...',
        ),
      ),
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  final String label;
  final List<T> items;
  final String Function(T) itemAsString;
  final void Function(String)? onAddOther;
  final void Function(T)? onEdit;
  final void Function(T)? onDelete;

  const _SearchDialog({
    required this.label,
    required this.items,
    required this.itemAsString,
    this.onAddOther,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = widget.items
          .where((item) => widget.itemAsString(item).toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('بحث: ${widget.label}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث هنا...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredItems.length + (widget.onAddOther != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _filteredItems.length) {
                    return ListTile(
                      leading: const Icon(Icons.add, color: Colors.green),
                      title: Text(
                        _searchController.text.isNotEmpty
                            ? '+ إضافة "${_searchController.text}" (غير ذلك)'
                            : '+ غير ذلك (إضافة جديد)',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        widget.onAddOther?.call(_searchController.text);
                      },
                    );
                  }

                  final item = _filteredItems[index];
                  return ListTile(
                    title: Text(widget.itemAsString(item)),
                    onTap: () => Navigator.pop(context, item),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => widget.onEdit?.call(item),
                          ),
                        if (widget.onDelete != null)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => widget.onDelete?.call(item),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
