import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:go_router/go_router.dart';
import '../config/api.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = '';
  String _status = 'Nhấn mic để nói';
  bool _isProcessing = false;
  
  // Parsed result
  Map<String, dynamic>? _parsedTransaction;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && _text.isNotEmpty) {
          _parseVoiceInput();
        }
      },
      onError: (error) {
        setState(() => _status = 'Lỗi: ${error.errorMsg}');
      },
    );
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _status = 'Đang nghe...';
          _text = '';
          _parsedTransaction = null;
        });
        _speech.listen(
          onResult: (result) {
            setState(() => _text = result.recognizedWords);
          },
          localeId: 'vi_VN',
        );
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      _status = 'Đang xử lý...';
    });
  }

  Future<void> _parseVoiceInput() async {
    if (_text.isEmpty) return;
    
    setState(() => _isProcessing = true);
    
    try {
      // Gọi API để parse text bằng AI
      final result = await apiService.parseVoiceTransaction(_text);
      
      setState(() {
        _parsedTransaction = result;
        _status = 'Đã nhận diện';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Không thể nhận diện. Thử lại?';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_parsedTransaction == null) return;
    
    setState(() => _isProcessing = true);
    
    try {
      await apiService.createTransaction({
        'categoryId': _parsedTransaction!['categoryId'],
        'amount': _parsedTransaction!['amount'],
        'type': _parsedTransaction!['type'],
        'description': _parsedTransaction!['description'],
        'transactionDate': DateTime.now().toIso8601String().split('T')[0],
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập bằng giọng nói'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue),
                  SizedBox(height: 8),
                  Text(
                    'Ví dụ: "Chi 50 nghìn ăn trưa" hoặc "Thu nhập 10 triệu lương tháng"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Mic button
            GestureDetector(
              onTapDown: (_) => _startListening(),
              onTapUp: (_) => _stopListening(),
              onTapCancel: () => _stopListening(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isListening ? 120 : 100,
                height: _isListening ? 120 : 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red : Colors.blue,
                  boxShadow: _isListening ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ] : null,
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 16)),
            
            const SizedBox(height: 20),
            
            // Recognized text
            if (_text.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bạn nói:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_text, style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Parsed result
            if (_parsedTransaction != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nhận diện:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildInfoRow('Loại', _parsedTransaction!['type'] == 'expense' ? 'Chi tiêu' : 'Thu nhập'),
                    _buildInfoRow('Số tiền', '${_formatCurrency(_parsedTransaction!['amount'])} đ'),
                    _buildInfoRow('Danh mục', _parsedTransaction!['categoryName'] ?? 'Khác'),
                    _buildInfoRow('Mô tả', _parsedTransaction!['description'] ?? ''),
                  ],
                ),
              ),
            
            const Spacer(),
            
            // Save button
            if (_parsedTransaction != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _saveTransaction,
                  icon: _isProcessing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                  label: const Text('Lưu giao dịch'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    double value;
    if (amount == null) {
      value = 0;
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0;
    } else if (amount is num) {
      value = amount.toDouble();
    } else {
      value = 0;
    }
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
