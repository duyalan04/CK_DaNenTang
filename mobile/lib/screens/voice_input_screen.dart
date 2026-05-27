import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/api.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  bool _isInitializingSpeech = true;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isParsing = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _lastParsedText;
  Map<String, dynamic>? _parsedTransaction;

  static const _quickSamples = [
    '50k cafe',
    '70k ăn trưa',
    '100k xăng xe',
    '15tr lương',
    '250k mua đồ',
    '120k tiền điện',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            final hadText = _controller.text.trim();
            setState(() => _isListening = false);
            if (hadText.isNotEmpty && _parsedTransaction == null && !_isParsing) {
              _parseTransaction(hadText);
            }
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _isSpeechAvailable = false;
            _errorMessage =
                'Thiết bị này không hỗ trợ nhận giọng nói ổn định. Bạn vẫn có thể ghi nhanh bằng văn bản.';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isSpeechAvailable = available;
        _isInitializingSpeech = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSpeechAvailable = false;
        _isInitializingSpeech = false;
        _errorMessage =
            'Thiết bị này không hỗ trợ nhận giọng nói. Bạn vẫn có thể ghi nhanh bằng văn bản.';
      });
    }
  }

  /// Dừng listening và parse nếu có text
  Future<void> _stopAndParse() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
    }
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      await _parseTransaction(text);
    }
  }

  Future<void> _toggleListening() async {
    if (_isParsing || _isSaving || _isInitializingSpeech) return;

    if (!_isSpeechAvailable) {
      _inputFocus.requestFocus();
      setState(() {
        _errorMessage =
            'Máy này không dùng được giọng nói. Hãy nhập nhanh bằng văn bản.';
      });
      return;
    }

    if (_isListening) {
      await _stopAndParse();
      return;
    }

    _inputFocus.unfocus();
    setState(() {
      _isListening = true;
      _errorMessage = null;
      _parsedTransaction = null;
      _lastParsedText = null;
    });

    await _speech.listen(
      localeId: 'vi_VN',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _speech.stop();
          _parseTransaction(result.recognizedWords.trim());
        }
      },
    );
  }

  Future<void> _parseFromInput() async {
    // Nếu đang nghe, dừng trước rồi parse
    if (_isListening) {
      await _stopAndParse();
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Nhập nội dung giao dịch, ví dụ: 50k cafe.';
        _parsedTransaction = null;
      });
      _inputFocus.requestFocus();
      return;
    }

    await _parseTransaction(text);
  }

  Future<void> _parseTransaction(String text) async {
    if (_isParsing) return;
    // Cho phép retry cùng text (không block bằng _lastParsedText)

    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _parsedTransaction = null;
      _lastParsedText = text;
    });

    try {
      final result = await apiService.parseTransactionText(text);
      final amount = _numValue(result['amount']);

      if (amount <= 0) {
        setState(() {
          _errorMessage =
              'Mình chưa nhận diện được số tiền. Thử nhập như: 50k cafe hoặc lương 15tr.';
          _isParsing = false;
          _lastParsedText = null;
        });
        return;
      }

      setState(() {
        _parsedTransaction = result;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể phân tích giao dịch lúc này. Thử lại sau.';
        _isParsing = false;
        _lastParsedText = null;
      });
    }
  }

  Future<void> _saveTransaction() async {
    final parsed = _parsedTransaction;
    if (parsed == null || _isSaving) return;

    final categoryId = parsed['categoryId'];
    final amount = _numValue(parsed['amount']);

    if (categoryId == null || categoryId.toString().isEmpty) {
      setState(() {
        _errorMessage =
            'Chưa tìm thấy danh mục phù hợp. Hãy tạo danh mục mặc định hoặc nhập thủ công.';
      });
      return;
    }

    if (amount <= 0) {
      setState(() => _errorMessage = 'Số tiền không hợp lệ.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await apiService.createTransaction({
        'categoryId': categoryId,
        'amount': amount,
        'type': parsed['type'] ?? 'expense',
        'description': parsed['description'] ?? _controller.text.trim(),
        'transactionDate': DateTime.now().toIso8601String().split('T')[0],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu giao dịch'),
          backgroundColor: Color(0xFF047857),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể lưu giao dịch. Kiểm tra kết nối rồi thử lại.';
        _isSaving = false;
      });
    }
  }

  void _useSample(String sample) {
    _controller.text = sample;
    _controller.selection = TextSelection.collapsed(offset: sample.length);
    _parseTransaction(sample);
  }

  num _numValue(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
    }
    return 0;
  }

  String _formatCurrency(dynamic amount) {
    final value = _numValue(amount);
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Cho phép bấm "Nhận diện" ngay cả khi đang nghe (sẽ tự stop rồi parse)
    final canSubmit = !_isParsing && !_isSaving;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Ghi nhanh giao dịch'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _InputPanel(
              controller: _controller,
              focusNode: _inputFocus,
              isListening: _isListening,
              isParsing: _isParsing,
              isSaving: _isSaving,
              isSpeechAvailable: _isSpeechAvailable,
              isInitializingSpeech: _isInitializingSpeech,
              onParse: canSubmit ? _parseFromInput : null,
              onToggleVoice: _toggleListening,
            ),
            const SizedBox(height: 14),
            _QuickSamples(
              samples: _quickSamples,
              enabled: canSubmit,
              onSelected: _useSample,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _MessageBanner(
                icon: Icons.info_outline,
                message: _errorMessage!,
                color: colorScheme.error,
              ),
            ],
            if (_isListening) ...[
              const SizedBox(height: 14),
              const _MessageBanner(
                icon: Icons.graphic_eq,
                message: 'Đang nghe. Nói ngắn gọn như: chi 50k ăn trưa.',
                color: Color(0xFF2563EB),
              ),
            ],
            if (!_isSpeechAvailable && !_isInitializingSpeech) ...[
              const SizedBox(height: 14),
              const _MessageBanner(
                icon: Icons.keyboard_alt_outlined,
                message:
                    'Giọng nói không khả dụng trên máy này. Nhập văn bản đang là chế độ chính.',
                color: Color(0xFF64748B),
              ),
            ],
            const SizedBox(height: 18),
            if (_isParsing)
              const _LoadingCard(label: 'Đang phân tích giao dịch...')
            else if (_parsedTransaction != null)
              _ParsedTransactionCard(
                transaction: _parsedTransaction!,
                formatCurrency: _formatCurrency,
              )
            else
              Text(
                'Nhập một câu ngắn để hệ thống tự nhận diện số tiền, loại giao dịch và danh mục.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _parsedTransaction == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveTransaction,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Đang lưu...' : 'Lưu giao dịch'),
                ),
              ),
            ),
    );
  }
}

class _InputPanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final bool isParsing;
  final bool isSaving;
  final bool isSpeechAvailable;
  final bool isInitializingSpeech;
  final VoidCallback? onParse;
  final VoidCallback onToggleVoice;

  const _InputPanel({
    required this.controller,
    required this.focusNode,
    required this.isListening,
    required this.isParsing,
    required this.isSaving,
    required this.isSpeechAvailable,
    required this.isInitializingSpeech,
    required this.onParse,
    required this.onToggleVoice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = isParsing || isSaving;
    final voiceColor = isListening
        ? const Color(0xFFDC2626)
        : isSpeechAvailable
            ? const Color(0xFF2563EB)
            : const Color(0xFF94A3B8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn đã chi hoặc nhận bao nhiêu?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ví dụ: 50k cafe, chi 70k ăn trưa, lương 15tr.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !disabled && !isListening,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onParse?.call(),
            decoration: InputDecoration(
              hintText: 'Nhập nhanh giao dịch...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              prefixIcon: const Icon(Icons.edit_note),
              suffixIcon: IconButton(
                onPressed: disabled || isInitializingSpeech
                    ? null
                    : onToggleVoice,
                icon: Icon(
                  isListening ? Icons.stop_circle_outlined : Icons.mic_none,
                  color: voiceColor,
                ),
                tooltip: isSpeechAvailable
                    ? 'Nhập bằng giọng nói'
                    : 'Giọng nói không khả dụng',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onParse,
              icon: isParsing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(isParsing ? 'Đang nhận diện...' : 'Nhận diện'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickSamples extends StatelessWidget {
  final List<String> samples;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const _QuickSamples({
    required this.samples,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: samples.map((sample) {
        return ActionChip(
          avatar: const Icon(Icons.bolt_outlined, size: 16),
          label: Text(sample),
          onPressed: enabled ? () => onSelected(sample) : null,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        );
      }).toList(),
    );
  }
}

class _ParsedTransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String Function(dynamic amount) formatCurrency;

  const _ParsedTransactionCard({
    required this.transaction,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction['type'] == 'income';
    final accent = isIncome ? const Color(0xFF047857) : const Color(0xFFDC2626);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isIncome ? Icons.south_west : Icons.north_east,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIncome ? 'Thu nhập' : 'Chi tiêu',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatCurrency(transaction['amount'])}đ',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF111827),
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: 'Danh mục',
            value: transaction['categoryName']?.toString() ?? 'Khác',
          ),
          _InfoRow(
            label: 'Mô tả',
            value: transaction['description']?.toString().trim().isEmpty == true
                ? 'Không có mô tả'
                : transaction['description']?.toString() ?? 'Không có mô tả',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _MessageBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String label;

  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
