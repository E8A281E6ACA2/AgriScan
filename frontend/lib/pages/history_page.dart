import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/export_helper.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Entitlements? _entitlements;
  final TextEditingController _cropFilterController = TextEditingController();
  final TextEditingController _minConfController = TextEditingController();
  final TextEditingController _maxConfController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadEntitlements();
  }

  @override
  void dispose() {
    _cropFilterController.dispose();
    _minConfController.dispose();
    _maxConfController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }
  
  Future<void> _loadHistory() async {
    final provider = context.read<AppProvider>();
    final api = context.read<ApiService>();
    
    try {
      final minConf = double.tryParse(_minConfController.text.trim());
      final maxConf = double.tryParse(_maxConfController.text.trim());
      final response = await api.getHistory(
        cropType: _cropFilterController.text.trim(),
        minConfidence: minConf,
        maxConfidence: maxConf,
        startDate: _startDateController.text.trim(),
        endDate: _endDateController.text.trim(),
      );
      provider.setHistory(response.results);
      provider.setSimilar(_findSimilar(response.results));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载历史失败: $e')),
        );
      }
    }
  }

  Future<void> _exportHistory(String format) async {
    final api = context.read<ApiService>();
    try {
      final minConf = double.tryParse(_minConfController.text.trim());
      final maxConf = double.tryParse(_maxConfController.text.trim());
      final bytes = await api.exportHistory(
        format: format,
        cropType: _cropFilterController.text.trim(),
        minConfidence: minConf,
        maxConfidence: maxConf,
        startDate: _startDateController.text.trim(),
        endDate: _endDateController.text.trim(),
      );
      final name = format == 'json' ? 'history.json' : 'history.csv';
      final path = await saveBytesAsFile(name, bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出成功: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _loadEntitlements() async {
    final api = context.read<ApiService>();
    try {
      final ent = await api.getEntitlements();
      if (mounted) setState(() => _entitlements = ent);
    } catch (_) {}
  }

  List<RecognizeResponse> _findSimilar(List<RecognizeResponse> history) {
    final result = context.read<AppProvider>().recognizeResult;
    if (result == null || result.cropType.isEmpty) return [];
    final crop = result.cropType;
    return history.where((h) => h.cropType == crop && h.imageUrl != null && h.imageUrl!.isNotEmpty).take(6).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final history = provider.history;
          
          return Stack(
            children: [
              Column(
                children: [
                  _buildFilterBar(),
                  Expanded(
                    child: history.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  '暂无识别记录',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _loadEntitlements();
                              await _loadHistory();
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: history.length,
                              itemBuilder: (context, index) {
                                final item = history[index];
                                return _buildHistoryCard(item);
                              },
                            ),
                          ),
                  ),
                ],
              ),
              if (_entitlements != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _buildEntitlementsFloat(_entitlements!),
                ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildHistoryCard(RecognizeResponse item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 作物图标
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.eco,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.eco,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              const SizedBox(width: 16),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCropName(item.cropType),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '置信度: ${(item.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // 箭头
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatCropName(String name) {
    if (name.isEmpty) return '未知作物';
    return name[0].toUpperCase() + name.substring(1);
  }
  
  void _showDetail(RecognizeResponse item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 把手
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.eco,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '识别详情',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.imageUrl!,
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
                const SizedBox(height: 16),
              ],
              
              _buildDetailRow('作物类型', _formatCropName(item.cropType)),
              _buildDetailRow('置信度', '${(item.confidence * 100).toStringAsFixed(1)}%'),
              _buildDetailRow('识别来源', item.provider),
              
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '详细描述',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(item.description),
              ],
              
              if (item.growthStage != null) ...[
                const SizedBox(height: 16),
                _buildDetailRow('生育期', item.growthStage!),
              ],
              
              if (item.possibleIssue != null) ...[
                const SizedBox(height: 16),
                _buildDetailRow('可能问题', item.possibleIssue!),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
      ),
    );
  }

  Widget _buildEntitlementsFloat(Entitlements ent) {
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

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _cropFilterController,
                  decoration: const InputDecoration(labelText: '作物(可选)'),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _minConfController,
                  decoration: const InputDecoration(labelText: '最小置信度'),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _maxConfController,
                  decoration: const InputDecoration(labelText: '最大置信度'),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _startDateController,
                  decoration: const InputDecoration(labelText: '开始日期(YYYY-MM-DD)'),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _endDateController,
                  decoration: const InputDecoration(labelText: '结束日期(YYYY-MM-DD)'),
                ),
              ),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('筛选'),
              ),
              OutlinedButton(
                onPressed: () => _exportHistory('csv'),
                child: const Text('导出CSV'),
              ),
              OutlinedButton(
                onPressed: () => _exportHistory('json'),
                child: const Text('导出JSON'),
              ),
              OutlinedButton(
                onPressed: () {
                  _cropFilterController.clear();
                  _minConfController.clear();
                  _maxConfController.clear();
                  _startDateController.clear();
                  _endDateController.clear();
                  _loadHistory();
                },
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
