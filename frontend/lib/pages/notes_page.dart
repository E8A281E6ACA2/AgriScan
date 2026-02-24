import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  DateTime? _startDate;
  DateTime? _endDate;
  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  static const List<String> _categories = [
    'all',
    'crop',
    'disease',
    'pest',
    'weed',
    'other',
  ];

  List<String> _cropTypes = ['all'];
  Map<String, String> _cropNameMap = {};

  static const List<String> _fieldOptions = [
    'id',
    'created_at',
    'image_id',
    'result_id',
    'image_url',
    'category',
    'crop_type',
    'confidence',
    'description',
    'growth_stage',
    'possible_issue',
    'provider',
    'note',
    'raw_text',
  ];

  static const Map<String, List<String>> _fieldPresets = {
    '轻量': [
      'id',
      'created_at',
      'image_url',
      'category',
      'crop_type',
      'confidence',
      'note',
    ],
    '完整': [
      'id',
      'created_at',
      'image_id',
      'result_id',
      'image_url',
      'category',
      'crop_type',
      'confidence',
      'description',
      'growth_stage',
      'possible_issue',
      'provider',
      'note',
    ],
    '研究用': [
      'id',
      'created_at',
      'image_id',
      'result_id',
      'image_url',
      'category',
      'crop_type',
      'confidence',
      'description',
      'growth_stage',
      'possible_issue',
      'provider',
      'note',
      'raw_text',
    ],
  };
  List<ExportTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadTemplates();
    _loadCrops();
  }

  Future<void> _loadNotes() async {
    final api = context.read<ApiService>();
    setState(() => _loading = true);
    try {
      final res = await api.getNotes(
        category: _category == 'all' ? null : _category,
        cropType: _cropType == 'all' ? null : _cropType,
        startDate: _startDate == null ? null : _dateFmt.format(_startDate!),
        endDate: _endDate == null ? null : _dateFmt.format(_endDate!),
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

  Future<void> _loadTemplates() async {
    final api = context.read<ApiService>();
    try {
      final items = await api.getExportTemplates(type: 'notes');
      if (mounted) setState(() => _templates = items);
    } catch (_) {}
  }

  Future<void> _loadCrops() async {
    final api = context.read<ApiService>();
    try {
      final items = await api.getCrops();
      if (!mounted) return;
      setState(() {
        _cropTypes = ['all', ...items.map((e) => e.code)];
        _cropNameMap = {for (final c in items) c.code: c.name};
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手记'),
        actions: [
          IconButton(
            onPressed: _showExportDialog,
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
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e == 'all' ? 'all' : '${_cropNameMap[e] ?? e} ($e)'),
                            ))
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(_startDate == null
                        ? '开始日期'
                        : _dateFmt.format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(_endDate == null
                        ? '结束日期'
                        : _dateFmt.format(_endDate!)),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _loadNotes();
                  },
                  icon: const Icon(Icons.clear),
                  tooltip: '清除日期',
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
                                    if (note.tags.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '标签: ${note.tags.join(", ")}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
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

  Future<void> _showExportDialog() async {
    final selected = Set<String>.from(_fieldPresets['完整']!);
    String format = 'csv';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('选择导出字段'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_templates.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          children: _templates.map((t) {
                            return OutlinedButton(
                              onPressed: () {
                                setStateDialog(() {
                                  selected
                                    ..clear()
                                    ..addAll(t.fields.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
                                });
                              },
                              child: Text(t.name),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 8,
                      children: _fieldPresets.keys.map((name) {
                        return OutlinedButton(
                          onPressed: () {
                            setStateDialog(() {
                              selected
                                ..clear()
                                ..addAll(_fieldPresets[name]!);
                            });
                          },
                          child: Text(name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('导出格式'),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: format,
                          items: const [
                            DropdownMenuItem(value: 'csv', child: Text('CSV')),
                            DropdownMenuItem(value: 'json', child: Text('JSON')),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setStateDialog(() {
                              format = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: _fieldOptions.map((f) {
                          final checked = selected.contains(f);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (val) {
                              setStateDialog(() {
                                if (val == true) {
                                  selected.add(f);
                                } else {
                                  selected.remove(f);
                                }
                              });
                            },
                            title: Text(f),
                            dense: true,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => setStateDialog(() {
                    selected
                      ..clear()
                      ..addAll(_fieldOptions);
                  }),
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: () => setStateDialog(() => selected.clear()),
                  child: const Text('清空'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    final name = await _promptTemplateName();
                    if (name == null || name.isEmpty) return;
                    final fields = selected.join(',');
                    if (fields.isEmpty) return;
                    await _saveTemplate(name, fields);
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('保存模板'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _exportNotes(selected.toList(), format: format);
                  },
                  child: const Text('导出'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportNotes(List<String> fields, {required String format}) async {
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
      if (_startDate != null) {
        params['start_date'] = _dateFmt.format(_startDate!);
      }
      if (_endDate != null) {
        params['end_date'] = _dateFmt.format(_endDate!);
      }
      if (fields.isNotEmpty) {
        params['fields'] = fields.join(',');
      }
      if (format.isNotEmpty) {
        params['format'] = format;
      }

      final bytes = await api.exportNotes(params);
      final filename = format == 'json' ? 'notes.json' : 'notes.csv';
      final contentType = format == 'json' ? 'application/json' : 'text/csv';
      final path = await saveBytesAsFile(filename, bytes, contentType: contentType);
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

  Future<void> _saveTemplate(String name, String fields) async {
    final api = context.read<ApiService>();
    try {
      await api.createExportTemplate(ExportTemplateRequest(
        name: name,
        fields: fields,
      ));
      await _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模板已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存模板失败: $e')),
        );
      }
    }
  }

  Future<String?> _promptTemplateName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('模板名称'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '例如：研究导出'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_endDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
    _loadNotes();
  }
}
