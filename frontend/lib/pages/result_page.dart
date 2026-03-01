import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedCorrection;
  bool _isSubmitting = false;
  bool _isSavingNote = false;
  String _noteCategory = 'crop';
  final List<String> _selectedTags = [];
  List<String> _availableTags = [];
  bool _feedbackSubmitted = false;
  bool _feedbackPrompted = false;
  List<Crop> _crops = [];
  String _feedbackCategory = 'crop';
  final List<String> _feedbackTags = [];
  String? _feedbackCorrectedType;
  Entitlements? _entitlements;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ApiService>().getHistory().then((res) {
          if (!mounted) return;
          context.read<AppProvider>().setHistory(res.results);
          final result = context.read<AppProvider>().recognizeResult;
          if (result == null) return;
          final crop = result.cropType;
          final similar = res.results
              .where((h) => h.cropType == crop && h.imageUrl != null && h.imageUrl!.isNotEmpty)
              .take(6)
              .toList();
          context.read<AppProvider>().setSimilar(similar);
        }).catchError((_) {}));
    _loadTags();
    _loadCrops();
    _loadEntitlements();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_feedbackPrompted) {
        _feedbackPrompted = true;
        _showQuickFeedback();
      }
    });
  }

  Future<void> _loadCrops() async {
    final api = context.read<ApiService>();
    try {
      final items = await api.getCrops();
      if (mounted) setState(() => _crops = items);
    } catch (_) {}
  }

  Future<void> _loadTags() async {
    final api = context.read<ApiService>();
    if (_noteCategory == 'crop' || _noteCategory == 'other') {
      setState(() => _availableTags = []);
      return;
    }
    try {
      final tags = await api.getTags(category: _noteCategory);
      if (mounted) {
        setState(() => _availableTags = tags);
      }
    } catch (_) {
      if (mounted) setState(() => _availableTags = []);
    }
  }

  Future<void> _loadEntitlements() async {
    final api = context.read<ApiService>();
    try {
      final ent = await api.getEntitlements();
      if (mounted) setState(() => _entitlements = ent);
    } catch (_) {}
  }
  
  final List<String> _commonCrops = [
    'wheat', 'corn', 'rice', 'soybean', 'cotton', 
    'potato', 'tomato', 'cabbage', 'lettuce', 'other'
  ];
  
  @override
  void dispose() {
    _feedbackController.dispose();
    _noteController.dispose();
    super.dispose();
  }
  
  Future<void> _submitFeedback(bool isCorrect) async {
    if (_isSubmitting) return;
    if (_feedbackSubmitted) return;
    
    setState(() => _isSubmitting = true);
    
    final provider = context.read<AppProvider>();
    final api = context.read<ApiService>();
    final result = provider.recognizeResult;
    
    if (result == null) return;
    
    try {
      await api.submitFeedback(FeedbackRequest(
        resultId: result.resultId,
        correctedType: _selectedCorrection,
        feedbackNote: _feedbackController.text,
        isCorrect: isCorrect,
        category: _noteCategory,
        tags: _selectedTags,
      ));
      _feedbackSubmitted = true;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('感谢您的反馈！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('反馈提交失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveNote() async {
    if (_isSavingNote) return;
    final provider = context.read<AppProvider>();
    final api = context.read<ApiService>();
    final result = provider.recognizeResult;
    final noteText = _noteController.text.trim();
    if (result == null) return;

    setState(() => _isSavingNote = true);
    try {
      await api.createNote(NoteRequest(
        imageId: result.imageId,
        resultId: result.resultId,
        note: noteText,
        category: _noteCategory,
        tags: _selectedTags,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('手记已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存手记失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNote = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final result = provider.recognizeResult;
        final imageBytes = provider.currentImageBytes;
        
        if (provider.state == AppState.loading) {
          return Scaffold(
            appBar: AppBar(title: const Text('识别中')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在识别作物...'),
                ],
              ),
            ),
          );
        }
        
        if (provider.state == AppState.error) {
          return Scaffold(
            appBar: AppBar(title: const Text('识别失败')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage ?? '识别失败，请重试'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('识别结果'),
            actions: [
              IconButton(
                icon: const Icon(Icons.feedback_outlined),
                tooltip: '纠错反馈',
                onPressed: () => _showQuickFeedback(),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  provider.reset();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // 相似样例
                  if (provider.similar.isNotEmpty) ...[
                  Text(
                    '相似样例（同作物历史）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final item = provider.similar[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrl ?? '',
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 88,
                              height: 88,
                              color: Colors.grey[200],
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: provider.similar.length,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // 图片展示
                if (imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imageBytes,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        alignment: Alignment.center,
                        child: const Text('图片加载失败'),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                
                // 识别结果卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.eco,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '识别结果',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        
                        // 作物名称
                        _buildResultRow('作物类型', result?.cropType ?? '未知'),
                        const SizedBox(height: 12),
                        
                        // 置信度
                        _buildConfidenceRow(result?.confidence ?? 0),
                        if (result?.confidenceLow != null && result?.confidenceHigh != null) ...[
                          const SizedBox(height: 12),
                          _buildResultRow(
                            '置信区间',
                            '${(result!.confidenceLow! * 100).toStringAsFixed(1)}% - ${(result.confidenceHigh! * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                        if (result?.riskLevel != null && result!.riskLevel!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildResultRow(
                            '风险等级',
                            result.riskLevel == 'low'
                                ? '低'
                                : result.riskLevel == 'medium'
                                    ? '中'
                                    : '高',
                          ),
                        ],
                        if (result?.riskNote != null && result!.riskNote!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildResultRow('风险提示', result.riskNote!),
                        ],
                        const SizedBox(height: 12),
                        
                        // 描述
                        _buildResultRow('详细描述', result?.description ?? '无'),
                        
                        if (result?.growthStage != null) ...[
                          const SizedBox(height: 12),
                          _buildResultRow('生育期', result!.growthStage!),
                        ],
                        
                        if (result?.possibleIssue != null) ...[
                          const SizedBox(height: 12),
                          _buildResultRow('可能问题', result!.possibleIssue!),
                        ],
                        
                        const SizedBox(height: 12),
                        _buildResultRow('识别提供商', result?.provider ?? '未知'),
                        if (result?.latitude != null && result?.longitude != null) ...[
                          const SizedBox(height: 12),
                          _buildResultRow(
                            '位置',
                            '${result!.latitude!.toStringAsFixed(6)}, ${result.longitude!.toStringAsFixed(6)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 识别说明与原始输出
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '识别说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result?.description ?? '暂无说明',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '提示：识别结果仅供参考，建议结合田间实际情况判断。',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        if (result?.rawText != null &&
                            result!.rawText!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('模型原始输出'),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  result.rawText!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 反馈区域
                Text(
                  '反馈纠错',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                
                // 快速纠错按钮
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('✅ 识别正确'),
                      selected: false,
                      onSelected: (_) => _submitFeedback(true),
                    ),
                    ChoiceChip(
                      label: const Text('❌ 识别错误'),
                      selected: false,
                      onSelected: (_) => _showCorrectionDialog(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 补充说明
                TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '补充说明（可选）',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 手记区域
                Text(
                  '手记',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('作物'),
                      selected: _noteCategory == 'crop',
                      onSelected: (_) => setState(() {
                        _noteCategory = 'crop';
                        _selectedTags.clear();
                        _availableTags = [];
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('病害'),
                      selected: _noteCategory == 'disease',
                      onSelected: (_) => setState(() {
                        _noteCategory = 'disease';
                        _selectedTags.clear();
                        _loadTags();
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('虫害'),
                      selected: _noteCategory == 'pest',
                      onSelected: (_) => setState(() {
                        _noteCategory = 'pest';
                        _selectedTags.clear();
                        _loadTags();
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('杂草'),
                      selected: _noteCategory == 'weed',
                      onSelected: (_) => setState(() {
                        _noteCategory = 'weed';
                        _selectedTags.clear();
                        _loadTags();
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('其他'),
                      selected: _noteCategory == 'other',
                      onSelected: (_) => setState(() {
                        _noteCategory = 'other';
                        _selectedTags.clear();
                        _availableTags = [];
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTagsChips(),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: '记录田间观察、用药情况、天气等',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingNote ? null : _saveNote,
                    icon: const Icon(Icons.save),
                    label: Text(_isSavingNote ? '保存中...' : '保存手记'),
                  ),
                ),

                const SizedBox(height: 24),
                
                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          provider.reset();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('重新识别'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          provider.reset();
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        icon: const Icon(Icons.home),
                        label: const Text('返回首页'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
                  ],
                ),
              ),
                if (_entitlements != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _buildMembershipBanner(_entitlements!),
                  ),
              ],
            ),
        );
      },
    );
  }

  Widget _buildMembershipBanner(Entitlements ent) {
    final isFree = ent.plan == 'free';
    final title = isFree ? '免费用户' : '会员：${ent.plan}';
    final subtitle = '剩余额度 ${ent.quotaRemaining} · 留存 ${ent.retentionDays} 天';
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: isFree ? Colors.orange.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
            if (isFree)
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/membership'),
                child: const Text('升级'),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
  
  Widget _buildConfidenceRow(double confidence) {
    final percent = (confidence * 100).toStringAsFixed(1);
    final label = confidence >= 0.85
        ? '高可信'
        : confidence >= 0.6
            ? '中等可信'
            : '低可信';
    final risk = confidence >= 0.85
        ? '风险低'
        : confidence >= 0.6
            ? '风险中'
            : '风险高';
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '置信度',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$percent%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Text(risk, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: confidence,
                backgroundColor: Colors.grey[200],
                color: confidence > 0.8 ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _showCorrectionDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请选择正确作物类型',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonCrops.map((crop) {
                return ChoiceChip(
                  label: Text(crop),
                  selected: _selectedCorrection == crop,
                  onSelected: (selected) {
                    setState(() => _selectedCorrection = selected ? crop : null);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickFeedback() async {
    if (_feedbackSubmitted) return;
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '这次识别是否正确？',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _submitFeedback(true);
                      },
                      child: const Text('正确'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showQuickCorrection();
                      },
                      child: const Text('错误'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('跳过'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showQuickCorrection() async {
    _feedbackCategory = 'crop';
    _feedbackTags.clear();
    _feedbackCorrectedType = _crops.isNotEmpty ? _crops.first.code : null;
    await _loadFeedbackTags();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择正确类型',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _feedbackCorrectedType,
                decoration: const InputDecoration(
                  labelText: '作物类型',
                  border: OutlineInputBorder(),
                ),
                items: _crops
                    .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text('${c.name} (${c.code})'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _feedbackCorrectedType = val),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('病害'),
                    selected: _feedbackCategory == 'disease',
                    onSelected: (_) => setState(() {
                      _feedbackCategory = 'disease';
                      _feedbackTags.clear();
                      _loadFeedbackTags();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('虫害'),
                    selected: _feedbackCategory == 'pest',
                    onSelected: (_) => setState(() {
                      _feedbackCategory = 'pest';
                      _feedbackTags.clear();
                      _loadFeedbackTags();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('杂草'),
                    selected: _feedbackCategory == 'weed',
                    onSelected: (_) => setState(() {
                      _feedbackCategory = 'weed';
                      _feedbackTags.clear();
                      _loadFeedbackTags();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((t) {
                  final selected = _feedbackTags.contains(t);
                  return FilterChip(
                    label: Text(t),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _feedbackTags.add(t);
                        } else {
                          _feedbackTags.remove(t);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _submitQuickFeedback();
                  },
                  child: const Text('提交'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadFeedbackTags() async {
    final api = context.read<ApiService>();
    try {
      final tags = await api.getTags(category: _feedbackCategory);
      if (mounted) {
        setState(() => _availableTags = tags);
      }
    } catch (_) {}
  }

  Future<void> _submitQuickFeedback() async {
    if (_isSubmitting || _feedbackSubmitted) return;
    final provider = context.read<AppProvider>();
    final api = context.read<ApiService>();
    final result = provider.recognizeResult;
    if (result == null) return;

    setState(() => _isSubmitting = true);
    try {
      await api.submitFeedback(FeedbackRequest(
        resultId: result.resultId,
        correctedType: _feedbackCorrectedType,
        feedbackNote: '',
        isCorrect: false,
        category: _feedbackCategory,
        tags: _feedbackTags,
      ));
      _feedbackSubmitted = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('感谢反馈')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('反馈失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildTagsChips() {
    final tags = _availableTags;
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final selected = _selectedTags.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: selected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _selectedTags.add(tag);
              } else {
                _selectedTags.remove(tag);
              }
            });
          },
        );
      }).toList(),
    );
  }

  
}
