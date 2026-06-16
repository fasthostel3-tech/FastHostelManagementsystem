import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';
import '../../config/theme.dart';

class MessManagementScreen extends ConsumerStatefulWidget {
  const MessManagementScreen({super.key});

  @override
  ConsumerState<MessManagementScreen> createState() => _MessManagementScreenState();
}

class _MessManagementScreenState extends ConsumerState<MessManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();
  late MessMenuItem _newItem;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _resetNewItem();
  }

  void _resetNewItem() {
    _newItem = MessMenuItem(
      name: '',
      price: 0,
      description: '',
      type: MealType.breakfast,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Menu Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(child: _buildTabButton('Breakfast', 0)),
                const SizedBox(width: 6),
                Expanded(child: _buildTabButton('Lunch', 1)),
                const SizedBox(width: 6),
                Expanded(child: _buildTabButton('Dinner', 2)),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate
                          .subtract(const Duration(days: 1));
                    });
                  },
                ),
                GestureDetector(
                  onTap: () => _showDatePicker(),
                  child: Text(
                    DateFormat('EEEE, MMMM d').format(_selectedDate),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                  },
                ),
              ],
            ),
          ),

          // Menu Display
          Expanded(
            child:             TabBarView(
              controller: _tabController,
              children: [
                _MenuTab(
                  date: _selectedDate,
                  type: MealType.breakfast,
                  onEdit: (item) => _showEditDialog(item),
                  onDelete: (item) => _deleteMenuItem(item),
                ),
                _MenuTab(
                  date: _selectedDate,
                  type: MealType.lunch,
                  onEdit: (item) => _showEditDialog(item),
                  onDelete: (item) => _deleteMenuItem(item),
                ),
                _MenuTab(
                  date: _selectedDate,
                  type: MealType.dinner,
                  onEdit: (item) => _showEditDialog(item),
                  onDelete: (item) => _deleteMenuItem(item),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Custom segmented tab button — guaranteed white text on navy background.
  Widget _buildTabButton(String label, int index) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final selected = _tabController.index == index;
        return Material(
          color: selected
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _tabController.animateTo(index);
              });
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _deleteMenuItem(MessMenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: const Text('Are you sure you want to delete this menu item?'),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dayOnly = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      await ref
          .read(messServiceProvider)
          .removeMenuItem(dayOnly, item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu item deleted')),
        );
      }
    }
  }

  Future<void> _showEditDialog(MessMenuItem? item) async {
      if (item != null) {
      _newItem = item;
    } else {
      _resetNewItem();
      // Set meal type based on tab index: 0=breakfast, 1=lunch, 2=dinner
      final mealTypes = [MealType.breakfast, MealType.lunch, MealType.dinner];
      _newItem = _newItem.copyWith(
        type: mealTypes[_tabController.index],
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: _newItem.name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter item name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _newItem = _newItem.copyWith(name: value);
                  },
                ),
                TextFormField(
                  initialValue: _newItem.price.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    hintText: 'Enter price',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _newItem = _newItem.copyWith(
                      price: double.tryParse(value!) ?? 0,
                    );
                  },
                ),
                TextFormField(
                  initialValue: _newItem.description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter description',
                  ),
                  maxLines: 3,
                  onSaved: (value) {
                    _newItem = _newItem.copyWith(description: value ?? '');
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _saveMenuItem(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMenuItem(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Normalize to midnight so the doc ID and `date` field both match
      // what the streams query for.
      final dayOnly = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      try {
        await ref
            .read(messServiceProvider)
            .addOrUpdateMenuItem(dayOnly, _newItem);

        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu item saved'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _MenuTab extends ConsumerWidget {
  final DateTime date;
  final MealType type;
  final Function(MessMenuItem) onEdit;
  final Function(MessMenuItem) onDelete;

  const _MenuTab({
    required this.date,
    required this.type,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<MessMenu?>(
      stream: ref.watch(messServiceProvider).getMenuForDateStream(date),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final menu = snapshot.data;
        final items = menu?.meals[type] ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == MealType.breakfast
                      ? Icons.free_breakfast_outlined
                      : type == MealType.lunch
                          ? Icons.lunch_dining_outlined
                          : Icons.dinner_dining_outlined,
                  size: 56,
                  color: AppColors.textDisabled,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No menu items available',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap + to add items for this meal',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = items[index];
            return Dismissible(
              key: Key(item.name),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onDelete(item),
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(item.name.isNotEmpty
                        ? item.name[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    item.description.isNotEmpty
                        ? item.description
                        : 'No description',
                  ),
                  trailing: Text(
                    'Rs. ${item.price.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  onTap: () => onEdit(item),
                ),
              ),
            );
          },
        );
      },
    );
  }
}