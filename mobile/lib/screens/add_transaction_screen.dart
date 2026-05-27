import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountFocus = FocusNode();

  String _type = 'expense';
  String? _categoryId;
  List<dynamic> _categories = [];
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();

  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  final _currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadCategories();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await apiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
      _animCtrl.forward();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool get _isValid =>
      _categoryId != null &&
      _amountController.text.isNotEmpty &&
      (double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0) > 0;

  String get _displayAmount {
    final raw = _amountController.text.replaceAll('.', '');
    final num = double.tryParse(raw) ?? 0;
    if (num == 0) return '0';
    return _currencyFmt.format(num).replaceAll('₫', '').trim();
  }

  Map<String, dynamic>? get _selectedCategory {
    if (_categoryId == null) return null;
    return _categories.cast<Map<String, dynamic>>().firstWhere(
          (c) => c['id'] == _categoryId,
          orElse: () => <String, dynamic>{},
        );
  }

  Color _parseColor(String? hex, {Color fallback = Colors.grey}) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _submit() async {
    if (!_isValid) return;

    setState(() => _isSaving = true);

    try {
      final rawAmount = _amountController.text.replaceAll('.', '');
      await apiService.createTransaction({
        'categoryId': _categoryId,
        'amount': double.parse(rawAmount),
        'type': _type,
        'description': _descriptionController.text.trim(),
        'transactionDate': _selectedDate.toIso8601String().split('T')[0],
      });

      if (!mounted) return;

      // Success haptic + snackbar
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Giao dịch đã được lưu!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = _type == 'expense';
    final accentColor = isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final filteredCategories =
        _categories.where((c) => c['type'] == _type).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Thêm giao dịch',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeIn,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // ── 1. Amount display ──
                    _AmountHeader(
                      displayAmount: _displayAmount,
                      type: _type,
                      accentColor: accentColor,
                      category: _selectedCategory,
                      parseColor: _parseColor,
                    ),
                    const SizedBox(height: 20),

                    // ── 2. Type toggle ──
                    _TypeToggle(
                      type: _type,
                      onChanged: (t) => setState(() {
                        _type = t;
                        _categoryId = null;
                      }),
                    ),
                    const SizedBox(height: 20),

                    // ── 3. Amount input ──
                    _SectionLabel(label: 'SỐ TIỀN'),
                    const SizedBox(height: 8),
                    _AmountField(
                      controller: _amountController,
                      focusNode: _amountFocus,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),

                    // ── 4. Category grid ──
                    _SectionLabel(label: 'DANH MỤC'),
                    const SizedBox(height: 8),
                    _CategoryGrid(
                      categories: filteredCategories,
                      selectedId: _categoryId,
                      onSelect: (id) => setState(() => _categoryId = id),
                      parseColor: _parseColor,
                    ),
                    const SizedBox(height: 20),

                    // ── 5. Description ──
                    _SectionLabel(label: 'GHI CHÚ'),
                    const SizedBox(height: 8),
                    _DescriptionField(controller: _descriptionController),
                    const SizedBox(height: 20),

                    // ── 6. Date picker ──
                    _SectionLabel(label: 'NGÀY'),
                    const SizedBox(height: 8),
                    _DateSelector(
                      date: _selectedDate,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      },
                    ),
                    const SizedBox(height: 32),

                    // ── 7. Submit button ──
                    _SubmitButton(
                      isValid: _isValid,
                      isSaving: _isSaving,
                      accentColor: accentColor,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════
// ── Sub-widgets ──
// ═══════════════════════════════════════════════

class _AmountHeader extends StatelessWidget {
  final String displayAmount;
  final String type;
  final Color accentColor;
  final Map<String, dynamic>? category;
  final Color Function(String?, {Color fallback}) parseColor;

  const _AmountHeader({
    required this.displayAmount,
    required this.type,
    required this.accentColor,
    required this.category,
    required this.parseColor,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = type == 'expense';
    final catColor = category != null
        ? parseColor(category!['color']?.toString())
        : accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.08),
            accentColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Category badge
          if (category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category!['icon']?.toString() ?? '📝',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category!['name']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: catColor,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isExpense ? 'Chi tiêu mới' : 'Thu nhập mới',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ),

          // Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isExpense ? '−' : '+',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: accentColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  displayAmount,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '₫',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: accentColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;

  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ToggleItem(
            label: 'Chi tiêu',
            icon: Icons.trending_down,
            isActive: type == 'expense',
            activeColor: const Color(0xFFEF4444),
            onTap: () => onChanged('expense'),
          ),
          _ToggleItem(
            label: 'Thu nhập',
            icon: Icons.trending_up,
            isActive: type == 'income',
            activeColor: const Color(0xFF10B981),
            onTap: () => onChanged('income'),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? activeColor : Colors.grey.shade400,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? activeColor : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade400,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accentColor;

  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _ThousandsSeparator(),
        ],
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(
            color: Colors.grey.shade300,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Container(
            width: 48,
            alignment: Alignment.center,
            child: Text(
              '₫',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: accentColor.withValues(alpha: 0.6),
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _ThousandsSeparator extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('.', '');
    if (text.isEmpty) return newValue.copyWith(text: '');

    final number = int.tryParse(text);
    if (number == null) return oldValue;

    final formatted = NumberFormat('#,###', 'vi_VN').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<dynamic> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final Color Function(String?, {Color fallback}) parseColor;

  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.parseColor,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'Chưa có danh mục',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((c) {
          final cat = c as Map<String, dynamic>;
          final id = cat['id']?.toString() ?? '';
          final name = cat['name']?.toString() ?? '';
          final icon = cat['icon']?.toString() ?? '📝';
          final color = parseColor(cat['color']?.toString());
          final isSelected = id == selectedId;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.12)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade200,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? color : Colors.grey.shade700,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, size: 16, color: color),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Thêm ghi chú (không bắt buộc)',
          hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
          prefixIcon: Icon(Icons.notes, color: Colors.grey.shade300, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateSelector({required this.date, required this.onTap});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) return 'Hôm nay';
    if (selected == today.subtract(const Duration(days: 1))) return 'Hôm qua';
    return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today, size: 18, color: Colors.blue.shade500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isValid;
  final bool isSaving;
  final Color accentColor;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.isValid,
    required this.isSaving,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: (isValid && !isSaving) ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: isValid ? accentColor : Colors.grey.shade200,
          foregroundColor: isValid ? Colors.white : Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: isValid ? 2 : 0,
          shadowColor: isValid ? accentColor.withValues(alpha: 0.3) : Colors.transparent,
        ),
        child: isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isValid ? Icons.check_circle_outline : Icons.block,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isValid ? 'Lưu giao dịch' : 'Nhập số tiền & chọn danh mục',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
