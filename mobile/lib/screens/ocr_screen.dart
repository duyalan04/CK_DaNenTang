import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../config/api.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  File? _image;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _categoryId;
  List<dynamic> _categories = [];
  Map<String, dynamic>? _aiResult;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await apiService.getCategories();
      setState(() => _categories = categories.where((c) => c['type'] == 'expense').toList());
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isProcessing = true;
        _aiResult = null;
      });
      await _analyzeWithAI();
    }
  }

  Future<void> _analyzeWithAI() async {
    if (_image == null) return;

    setState(() {
      _isProcessing = true;
      _aiResult = null;
    });

    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      print('📸 Sending image to OCR API, size: ${bytes.length} bytes');

      final result = await apiService.analyzeReceiptWithAI(base64Image);

      print('🔍 OCR Result: ${result['success']}');
      
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'OCR failed');
      }

      setState(() {
        _aiResult = result;
        _isProcessing = false;

        // Auto-select category
        if (result['suggestedCategory'] != null) {
          _autoSelectCategory(result['suggestedCategory']);
        }

        // Auto-select date
        if (result['date'] != null) {
          try {
            _selectedDate = DateTime.parse(result['date']);
          } catch (e) {
            print('⚠️ Failed to parse date: $e');
          }
        }
      });
    } catch (e) {
      print('❌ OCR Error: $e');
      setState(() {
        _isProcessing = false;
        _aiResult = {
          'success': false, 
          'error': e.toString().replaceAll('Exception: ', '')
        };
      });
    }
  }

  void _autoSelectCategory(String suggested) {
    final suggestedLower = suggested.toLowerCase();
    
    for (final cat in _categories) {
      final catName = cat['name'].toString().toLowerCase();
      if (catName.contains(suggestedLower) || suggestedLower.contains(catName)) {
        setState(() => _categoryId = cat['id']);
        return;
      }
    }

    // Mapping aliases
    final Map<String, List<String>> categoryAliases = {
      'ăn uống': ['food', 'restaurant', 'cafe', 'nhà hàng', 'quán'],
      'mua sắm': ['shopping', 'store', 'cửa hàng', 'siêu thị'],
      'sức khỏe': ['health', 'pharmacy', 'thuốc', 'spa', 'massage'],
      'di chuyển': ['transport', 'taxi', 'grab', 'xăng'],
      'giải trí': ['entertainment', 'movie', 'game'],
    };

    for (final cat in _categories) {
      final catName = cat['name'].toString().toLowerCase();
      for (final entry in categoryAliases.entries) {
        if (catName.contains(entry.key)) {
          if (entry.value.any((alias) => suggestedLower.contains(alias))) {
            setState(() => _categoryId = cat['id']);
            return;
          }
        }
      }
    }
  }

  String _formatCurrency(num? value) {
    if (value == null) return 'N/A';
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(value);
  }

  Future<void> _saveTransaction() async {
    if (_aiResult == null || _aiResult!['success'] != true || _categoryId == null) return;

    setState(() => _isSaving = true);

    try {
      await apiService.createFromOCR({
        'ocrData': {
          'rawText': _aiResult!['storeName'] ?? '',
          'extractedAmount': _aiResult!['totalAmount'],
          'extractedItems': (_aiResult!['items'] as List?)?.map((i) => i['name']).toList() ?? [],
          'aiAnalysis': _aiResult,
        },
        'categoryId': _categoryId,
        'transactionDate': _selectedDate.toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã lưu giao dịch thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _aiResult = null;
      _categoryId = null;
      _selectedDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét hóa đơn AI'),
        actions: [
          if (_image != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Chụp lại',
            ),
        ],
      ),
      body: _image == null ? _buildPickerView() : _buildResultView(),
    );
  }

  Widget _buildPickerView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(Icons.document_scanner, size: 80, color: Colors.teal.shade400),
                const SizedBox(height: 24),
                const Text(
                  'Quét hóa đơn bằng AI',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chụp ảnh hoặc chọn từ thư viện\nAI sẽ tự động nhận dạng thông tin',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Chụp ảnh'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.teal,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Thư viện'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Hỗ trợ: GS25, Circle K, Siêu thị, Nhà hàng, Spa...',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image preview
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _image!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),

        if (_isProcessing)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('AI đang phân tích hóa đơn...'),
                  const SizedBox(height: 8),
                  Text(
                    'Vui lòng đợi trong giây lát',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else if (_aiResult != null) ...[
          if (_aiResult!['success'] == true) ...[
            // Success result
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Độ tin cậy: ${_aiResult!['confidence'] ?? 'N/A'}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _InfoRow(label: 'Cửa hàng', value: _aiResult!['storeName'] ?? 'N/A'),
                    if (_aiResult!['storeAddress'] != null)
                      _InfoRow(label: 'Địa chỉ', value: _aiResult!['storeAddress']),
                    _InfoRow(label: 'Ngày', value: _aiResult!['date'] ?? 'N/A'),
                    _InfoRow(
                      label: 'Tổng tiền',
                      value: _formatCurrency(_aiResult!['totalAmount']),
                      isHighlight: true,
                    ),
                    if (_aiResult!['discountAmount'] != null && _aiResult!['discountAmount'] > 0)
                      _InfoRow(
                        label: 'Giảm giá',
                        value: '-${_formatCurrency(_aiResult!['discountAmount'])}',
                      ),
                    _InfoRow(
                      label: 'Gợi ý danh mục',
                      value: _aiResult!['suggestedCategory'] ?? 'N/A',
                    ),
                  ],
                ),
              ),
            ),

            // Items list
            if (_aiResult!['items'] != null && (_aiResult!['items'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  title: Text('Chi tiết (${(_aiResult!['items'] as List).length} sản phẩm)'),
                  children: [
                    ...(_aiResult!['items'] as List).map((item) => ListTile(
                          dense: true,
                          title: Text(item['name'] ?? ''),
                          subtitle: Text('SL: ${item['quantity'] ?? 1}'),
                          trailing: Text(_formatCurrency(item['total'] ?? item['unitPrice'])),
                        )),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Category selector
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: InputDecoration(
                labelText: 'Danh mục',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.category),
              ),
              items: _categories.map<DropdownMenuItem<String>>((c) {
                return DropdownMenuItem(value: c['id'], child: Text(c['name']));
              }).toList(),
              onChanged: (value) => setState(() => _categoryId = value),
            ),

            const SizedBox(height: 16),

            // Date selector
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Ngày giao dịch'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
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
          ] else
            // Error result
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Không thể phân tích hóa đơn',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _aiResult!['error'] ?? 'Lỗi không xác định',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      '💡 Gợi ý:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Chụp ảnh rõ ràng, không bị mờ\n'
                      '• Đảm bảo đủ ánh sáng\n'
                      '• Hóa đơn phải có số tiền rõ ràng\n'
                      '• Thử chụp lại hoặc chọn ảnh khác',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Chụp lại'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _aiResult!['success'] == true && _categoryId != null && !_isSaving
                      ? _saveTransaction
                      : null,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Đang lưu...' : 'Lưu giao dịch'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.teal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlight ? 20 : 14,
              color: isHighlight ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
