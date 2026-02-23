import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final TextEditingController _feedbackController = TextEditingController();
  String? _selectedCorrection;
  bool _isSubmitting = false;
  
  final List<String> _commonCrops = [
    'wheat', 'corn', 'rice', 'soybean', 'cotton', 
    'potato', 'tomato', 'cabbage', 'lettuce', 'other'
  ];
  
  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
  
  Future<void> _submitFeedback(bool isCorrect) async {
    if (_isSubmitting) return;
    
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
      ));
      
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
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final result = provider.recognizeResult;
        final image = provider.currentImage;
        
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
                  Text(provider.errorMessage ?? '未知错误'),
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
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  provider.reset();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图片展示
                if (image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      image,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
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
        );
      },
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
              Text(
                '$percent%',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
}
