import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Entitlements? _entitlements;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadEntitlements();
  }
  
  Future<void> _loadHistory() async {
    final provider = context.read<AppProvider>();
    final api = context.read<ApiService>();
    
    try {
      final response = await api.getHistory();
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
          
          if (history.isEmpty) {
            return const Center(
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
            );
          }
          
          return RefreshIndicator(
            onRefresh: () async {
              await _loadEntitlements();
              await _loadHistory();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length + (_entitlements == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (_entitlements != null && index == 0) {
                  return _buildEntitlementsBanner(_entitlements!);
                }
                final item = history[index - (_entitlements == null ? 0 : 1)];
                return _buildHistoryCard(item);
              },
            ),
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

  Widget _buildEntitlementsBanner(Entitlements ent) {
    final isFree = ent.plan == 'free';
    final title = isFree ? '升级会员，获取更高额度' : '当前会员：${ent.plan}';
    final subtitle = isFree
        ? '更高额度与更长留存'
        : '剩余额度 ${ent.quotaRemaining}，留存 ${ent.retentionDays} 天';
    return Card(
      color: isFree ? Colors.orange.shade50 : Colors.green.shade50,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: isFree
            ? ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/membership'),
                child: const Text('升级'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
