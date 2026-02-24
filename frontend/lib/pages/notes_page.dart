import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/export_helper.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  bool _loading = true;
  List<Note> _notes = [];
  String _category = 'all';
  String _cropType = 'all';

  static const List<String> _categories = [
    'all',
    'crop',
    'disease',
    'pest',
    'weed',
    'other',
  ];

  static const List<String> _cropTypes = [
    'all',
    'corn',
    'wheat',
    'rice',
    'soybean',
    'tomato',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final api = context.read<ApiService>();
    setState(() => _loading = true);
    try {
      final res = await api.getNotes(
        category: _category == 'all' ? null : _category,
        cropType: _cropType == 'all' ? null : _cropType,
      );
      setState(() => _notes = res.results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载手记失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手记'),
        actions: [
          IconButton(
            onPressed: _exportNotes,
            icon: const Icon(Icons.download),
            tooltip: '导出CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _category = val);
                      _loadNotes();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _cropType,
                    decoration: const InputDecoration(
                      labelText: '作物',
                      border: OutlineInputBorder(),
                    ),
                    items: _cropTypes
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _cropType = val);
                      _loadNotes();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Text('暂无手记'),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (note.imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    note.imageUrl,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 72,
                                      height: 72,
                                      color: Colors.grey[200],
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 72,
                                  height: 72,
                                  color: Colors.grey[200],
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.image),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.note.isEmpty ? '（无备注）' : note.note,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (note.cropType != null && note.cropType!.isNotEmpty)
                                      Text(
                                        '识别: ${note.cropType}  ${((note.confidence ?? 0) * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '类型: ${note.category}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      note.createdAt,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportNotes() async {
    final api = context.read<ApiService>();
    try {
      final params = <String, dynamic>{
        'limit': 1000,
        'offset': 0,
      };
      if (_category != 'all') {
        params['category'] = _category;
      }
      if (_cropType != 'all') {
        params['crop_type'] = _cropType;
      }

      final bytes = await api.exportNotes(params);
      final path = await saveBytesAsFile('notes.csv', bytes);
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
}
