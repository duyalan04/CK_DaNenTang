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
  
  // Kết quả từ AI
  Map<String, dynamic>? _aiResult;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await apiService.getCategories();
    setState(() => _categories = categories.where((c) => c['type'] == 'expense').toList());
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);

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

    try {
      // Convert image to base64
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Gọi API phân tích
      final result = await apiService.analyzeReceiptWithAI(base64Image);

      setState(() {
        _aiResult = result;
        _isProcessing = false;
        
        // Tự động chọn category dựa trên gợi ý của AI
        if (result['success'] == true && result['suggestedCategory'] != null) {
          _autoSelectCategory(result['suggestedCategory']);
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _aiResult = {'success': false, 'error': e.toString()};
      });
    }
  }

  void _autoSelectCategory(String suggested) {
    final categoryMap = {
      'Ăn uống': ['ăn uống', 'food', 'restaurant', 'cafe'],
      'Mua sắm': ['mua sắm', 'shopping'],
      'Di chuyển': ['di chuyển', 'transport', 'taxi', 'grab'],
      'Hóa đơn': ['hóa đơn', 'bill', 'điện', 'nước'],
      'Sức khỏe': ['sức khỏe', 'health', 'pharmacy', 'thuốc'],
      'Giải trí': ['giải trí', 'entertainment'],
    };

    for (final cat in _categories) {
      final catName = cat['name'].toString().toLowerCase();
      final suggestedLower = suggested.toLowerCase();
      
      if (catName.contains(suggestedLower) || suggestedLower.contains(catName)) {
        setState(() => _categoryId = cat['id']);
        return;
      }
      
      // Check aliases
      for (final entry in categoryMap.entries) {
        if (entry.value.any((alias) => suggestedLower.contains(alias))) {
          if (catName.contains(entry.key.toLowerCase())) {
            setState(() => _categoryId = cat['id']);
            return;
          }
        }
      }
    }
  }

  String _formatCurrency(num? value) {
    if (value == null) return 'N/A';
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
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
        'transactionDate': _aiResult!['date'] ?? DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu giao dịch!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét hóa đơn AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_image == null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.document_scanner, size: 64, color: Colors.blue.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Chụp hoặc chọn ảnh hóa đơn\nAI sẽ tự động nhận dạng thông tin',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Chụp ảnh'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Hiển thị ảnh
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_image!, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),

            if (_isProcessing)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('AI đang phân tích hóa đơn...'),
                    ],
                  ),
                ),
              )
            else if (_aiResult != null) ...[
              // Kết quả AI
              if (_aiResult!['success'] == true) ...[
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
                            Text('Độ tin cậy: ${_aiResult!['confidence'] ?? 'N/A'}%',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(),
                        _InfoRow(label: 'Cửa hàng', value: _aiResult!['storeName'] ?? 'N/A'),
                        _InfoRow(label: 'Ngày', value: _aiResult!['date'] ?? 'N/A'),
                        _InfoRow(
                          label: 'Tổng tiền',
                          value: _formatCurrency(_aiResult!['totalAmount']),
                          isHighlight: true,
                        ),
                        if (_aiResult!['discountAmount'] != null && _aiResult!['discountAmount'] > 0)
                          _InfoRow(label: 'Giảm giá', value: _formatCurrency(_aiResult!['discountAmount'])),
                        _InfoRow(label: 'Gợi ý danh mục', value: _aiResult!['suggestedCategory'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ),

                // Danh sách sản phẩm
                if (_aiResult!['items'] != null && (_aiResult!['items'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ExpansionTile(
                      title: Text('Chi tiết (${(_aiResult!['items'] as List).length} sản phẩm)'),
                      children: [
                        ...(_aiResult!['items'] as List).map((item) => ListTile(
                              dense: true,
                              title: Text(item['name'] ?? ''),
                              trailing: Text(_formatCurrency(item['total'] ?? item['price'])),
                            )),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map<DropdownMenuItem<String>>((c) {
                    return DropdownMenuItem(value: c['id'], child: Text(c['name']));
                  }).toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              ] else
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_aiResult!['error'] ?? 'Không thể phân tích')),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _image = null;
                        _aiResult = null;
                        _categoryId = null;
                      }),
                      child: const Text('Chụp lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _aiResult!['success'] == true && _categoryId != null && !_isSaving
                          ? _saveTransaction
                          : null,
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Lưu giao dịch'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _InfoRow({required this.label, required this.value, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlight ? 18 : 14,
              color: isHighlight ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
