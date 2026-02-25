import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../utils/export_helper.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _tokenController = TextEditingController();
  final _searchController = TextEditingController();
  final _logEmailController = TextEditingController();
  final _reqStatusController = TextEditingController(text: 'pending');
  final _quotaDeltaController = TextEditingController(text: '1000');
  final _quotaController = TextEditingController();
  final _usedController = TextEditingController();
  final _creditsController = TextEditingController();

  bool _loading = false;
  List<AdminUser> _users = [];
  List<EmailLog> _logs = [];
  List<MembershipRequest> _requests = [];
  List<AdminAuditLog> _audits = [];
  List<AdminLabelNote> _labelNotes = [];
  List<PlanSetting> _planSettings = [];
  AdminStats? _stats;
  EvalSummary? _eval;
  AdminUser? _selected;
  String _plan = 'free';
  String _status = 'active';
  final bool _enableLabelFlow = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _searchController.dispose();
    _logEmailController.dispose();
    _reqStatusController.dispose();
    _quotaDeltaController.dispose();
    _quotaController.dispose();
    _usedController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final users = await api.adminListUsers(
        adminToken: token.isEmpty ? null : token,
        q: _searchController.text.trim(),
      );
      setState(() => _users = users);
    } catch (e) {
      _toast('拉取用户失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final stats = await api.adminStats(adminToken: token.isEmpty ? null : token);
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      _toast('统计加载失败: $e');
    }
  }

  void _selectUser(AdminUser user) {
    setState(() {
      _selected = user;
      _plan = user.plan;
      _status = user.status;
      _quotaController.text = user.quotaTotal.toString();
      _usedController.text = user.quotaUsed.toString();
      _creditsController.text = user.adCredits.toString();
    });
  }

  Future<void> _saveUser() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final user = _selected;
    if (token.isEmpty || user == null) return;
    setState(() => _loading = true);
    try {
      final updated = await api.adminUpdateUser(
        user.id,
        AdminUserUpdate(
          plan: _plan,
          status: _status,
          quotaTotal: int.tryParse(_quotaController.text),
          quotaUsed: int.tryParse(_usedController.text),
          adCredits: int.tryParse(_creditsController.text),
        ),
        adminToken: token,
      );
      _selectUser(updated);
      await _loadUsers();
      _toast('保存成功');
    } catch (e) {
      _toast('保存失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembershipRequests() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final status = _reqStatusController.text.trim();
      final items = await api.adminListMembershipRequests(
        adminToken: token.isEmpty ? null : token,
        status: status.isEmpty ? null : status,
      );
      setState(() => _requests = items);
    } catch (e) {
      _toast('拉取申请失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveRequest(MembershipRequest req) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      await api.adminApproveMembershipRequest(req.id, plan: req.plan, adminToken: token.isEmpty ? null : token);
      _toast('已通过');
      await _loadMembershipRequests();
    } catch (e) {
      _toast('操作失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addQuota() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final user = _selected;
    if (user == null) return;
    final delta = int.tryParse(_quotaDeltaController.text) ?? 0;
    if (delta <= 0) {
      _toast('请输入正确的充值额度');
      return;
    }
    setState(() => _loading = true);
    try {
      final updated = await api.adminAddQuota(user.id, delta: delta, adminToken: token.isEmpty ? null : token);
      _selectUser(updated);
      await _loadUsers();
      _toast('充值成功');
    } catch (e) {
      _toast('充值失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rejectRequest(MembershipRequest req) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      await api.adminRejectMembershipRequest(req.id, adminToken: token.isEmpty ? null : token);
      _toast('已拒绝');
      await _loadMembershipRequests();
    } catch (e) {
      _toast('操作失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEmailLogs() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final logs = await api.adminListEmailLogs(
        adminToken: token.isEmpty ? null : token,
        email: _logEmailController.text.trim(),
      );
      setState(() => _logs = logs);
    } catch (e) {
      _toast('拉取邮件日志失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final items = await api.adminAuditLogs(adminToken: token.isEmpty ? null : token);
      setState(() => _audits = items);
    } catch (e) {
      _toast('审计日志失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLabelQueue() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final items = await api.adminLabelQueue(adminToken: token.isEmpty ? null : token);
      setState(() => _labelNotes = items);
    } catch (e) {
      _toast('标注队列失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPlanSettings() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final items = await api.adminPlanSettings(adminToken: token.isEmpty ? null : token);
      setState(() => _planSettings = items);
    } catch (e) {
      _toast('会员配置失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editPlanSetting(PlanSetting plan) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final nameController = TextEditingController(text: plan.name);
    final descController = TextEditingController(text: plan.description);
    final quotaController = TextEditingController(text: plan.quotaTotal.toString());
    final retentionController = TextEditingController(text: plan.retentionDays.toString());
    bool requireAd = plan.requireAd;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('编辑 ${plan.code}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '描述'),
                ),
                TextField(
                  controller: quotaController,
                  decoration: const InputDecoration(labelText: '额度总数'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: retentionController,
                  decoration: const InputDecoration(labelText: '留存天数'),
                  keyboardType: TextInputType.number,
                ),
                StatefulBuilder(
                  builder: (context, setState) {
                    return CheckboxListTile(
                      value: requireAd,
                      onChanged: (v) => setState(() => requireAd = v ?? false),
                      title: const Text('需要广告'),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        );
      },
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await api.adminUpdatePlanSetting(
        plan.code,
        PlanSettingUpdate(
          name: nameController.text.trim(),
          description: descController.text.trim(),
          quotaTotal: int.tryParse(quotaController.text.trim()),
          retentionDays: int.tryParse(retentionController.text.trim()),
          requireAd: requireAd,
        ),
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已保存');
      await _loadPlanSettings();
    } catch (e) {
      _toast('保存失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEval() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final summary = await api.adminEvalSummary(adminToken: token.isEmpty ? null : token);
      setState(() => _eval = summary);
    } catch (e) {
      _toast('评测加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportUsers() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportUsers(adminToken: token.isEmpty ? null : token);
      final path = await saveBytesAsFile('users.csv', bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
    }
  }

  Future<void> _exportNotes() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportNotes(adminToken: token.isEmpty ? null : token);
      final path = await saveBytesAsFile('notes_admin.csv', bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
    }
  }

  Future<void> _exportFeedback() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportFeedback(adminToken: token.isEmpty ? null : token);
      final path = await saveBytesAsFile('feedback.csv', bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
    }
  }

  Future<void> _exportEvalCsv() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportEval(format: 'csv', adminToken: token.isEmpty ? null : token);
      final path = await saveBytesAsFile('eval_dataset.csv', bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
    }
  }

  Future<void> _exportEvalJson() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportEval(format: 'json', adminToken: token.isEmpty ? null : token);
      final path = await saveBytesAsFile('eval_dataset.json', bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
    }
  }

  Future<void> _labelNote(AdminLabelNote note) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final categoryController = TextEditingController(text: note.category);
    final cropController = TextEditingController(text: note.cropType);
    final tagsController = TextEditingController(text: note.labelTags);
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('标注'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: '类别'),
              ),
              TextField(
                controller: cropController,
                decoration: const InputDecoration(labelText: '作物'),
              ),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(labelText: '标签(逗号)'),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: '备注'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('提交')),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await api.adminLabelNote(
        note.id,
        category: categoryController.text.trim(),
        cropType: cropController.text.trim(),
        tags: tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        note: noteController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      _toast('标注成功');
      await _loadLabelQueue();
    } catch (e) {
      _toast('标注失败: $e');
    }
  }

  Future<void> _reviewLabel(AdminLabelNote note, String status) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      await api.adminReviewLabel(note.id, status: status, adminToken: token.isEmpty ? null : token);
      _toast('已${status == 'approved' ? '通过' : '拒绝'}');
      await _loadLabelQueue();
    } catch (e) {
      _toast('审核失败: $e');
    }
  }

  Future<void> _purgeUser() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final user = _selected;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      await api.adminPurgeUser(user.id, adminToken: token.isEmpty ? null : token);
      _toast('清理完成');
    } catch (e) {
      _toast('清理失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理后台')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: '管理员 Token（可选）',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _loadStats,
                  child: const Text('刷新统计'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _exportUsers,
                  child: const Text('导出用户'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _exportNotes,
                  child: const Text('导出手记'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _exportFeedback,
                  child: const Text('导出反馈'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _exportEvalCsv,
                  child: const Text('导出评测CSV'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _exportEvalJson,
                  child: const Text('导出评测JSON'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_stats != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _statChip('用户', _stats!.usersTotal),
                      _statChip('7日活跃', _stats!.usersActive7d),
                      _statChip('图片', _stats!.imagesTotal),
                      _statChip('结果', _stats!.resultsTotal),
                      _statChip('手记', _stats!.notesTotal),
                      _statChip('反馈', _stats!.feedbackTotal),
                      _statChip('待审批', _stats!.membershipPending),
                      _statChip('待标注', _stats!.labelPending),
                      _statChip('已审核', _stats!.labelApproved),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(labelText: '搜索邮箱/昵称'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _loadUsers,
                  child: const Text('搜索'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            children: _users.map((u) {
                              final adminTag = u.isAdmin ? ' | admin' : '';
                              return ListTile(
                                title: Text(u.email),
                                subtitle: Text('${u.plan} | used ${u.quotaUsed}$adminTag'),
                                selected: _selected?.id == u.id,
                                onTap: () => _selectUser(u),
                              );
                            }).toList(),
                          ),
                  ),
                  const VerticalDivider(),
                  Expanded(
                    flex: 3,
                    child: _selected == null
                        ? const Center(child: Text('选择用户'))
                        : ListView(
                            children: [
                              DropdownButtonFormField<String>(
                                value: _plan,
                                items: const [
                                  DropdownMenuItem(value: 'free', child: Text('free')),
                                  DropdownMenuItem(value: 'silver', child: Text('silver')),
                                  DropdownMenuItem(value: 'gold', child: Text('gold')),
                                  DropdownMenuItem(value: 'diamond', child: Text('diamond')),
                                ],
                                onChanged: (v) => setState(() => _plan = v ?? 'free'),
                                decoration: const InputDecoration(labelText: '会员档次'),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _status,
                                items: const [
                                  DropdownMenuItem(value: 'active', child: Text('active')),
                                  DropdownMenuItem(value: 'guest', child: Text('guest')),
                                  DropdownMenuItem(value: 'disabled', child: Text('disabled')),
                                ],
                                onChanged: (v) => setState(() => _status = v ?? 'active'),
                                decoration: const InputDecoration(labelText: '状态'),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _quotaController,
                                decoration: const InputDecoration(labelText: '额度总数'),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _usedController,
                                decoration: const InputDecoration(labelText: '已用额度'),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _creditsController,
                                decoration: const InputDecoration(labelText: '广告次数余额'),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _loading ? null : _saveUser,
                                    child: const Text('保存'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _loading ? null : _addQuota,
                                    child: const Text('充值额度'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _loading ? null : _purgeUser,
                                    child: const Text('按留存清理'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _quotaDeltaController,
                                decoration: const InputDecoration(labelText: '充值额度（增量）'),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('邮件日志', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _logEmailController,
                                      decoration: const InputDecoration(labelText: '邮箱（可选）'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _loadEmailLogs,
                                    child: const Text('查询'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._logs.map((log) {
                                return ListTile(
                                  dense: true,
                                  title: Text('${log.email}  (${log.status})'),
                                  subtitle: Text(log.error.isEmpty ? log.createdAt : '${log.createdAt} | ${log.error}'),
                                  trailing: Text(log.code),
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('审计日志', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loading ? null : _loadAuditLogs,
                                child: const Text('刷新审计'),
                              ),
                              const SizedBox(height: 8),
                              ..._audits.map((a) {
                                return ListTile(
                                  dense: true,
                                  title: Text('${a.action} ${a.targetType}#${a.targetId}'),
                                  subtitle: Text('${a.createdAt} | ${a.ip}'),
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('会员申请', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _reqStatusController,
                                      decoration: const InputDecoration(labelText: '状态(pending/approved/rejected)'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _loadMembershipRequests,
                                    child: const Text('查询'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._requests.map((req) {
                                return Card(
                                  child: ListTile(
                                    title: Text('User ${req.userId} · ${req.plan} · ${req.status}'),
                                    subtitle: Text(req.note.isEmpty ? req.createdAt : '${req.createdAt} | ${req.note}'),
                                    trailing: req.status == 'pending'
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                onPressed: _loading ? null : () => _approveRequest(req),
                                                icon: const Icon(Icons.check, color: Colors.green),
                                              ),
                                              IconButton(
                                                onPressed: _loading ? null : () => _rejectRequest(req),
                                                icon: const Icon(Icons.close, color: Colors.red),
                                              ),
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('会员配置', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loading ? null : _loadPlanSettings,
                                child: const Text('刷新配置'),
                              ),
                              const SizedBox(height: 8),
                              ..._planSettings.map((p) {
                                return Card(
                                  child: ListTile(
                                    title: Text('${p.code} · ${p.name}'),
                                    subtitle: Text('额度 ${p.quotaTotal} · 留存 ${p.retentionDays} 天 · 广告 ${p.requireAd ? "是" : "否"}'),
                                    trailing: IconButton(
                                      onPressed: _loading ? null : () => _editPlanSetting(p),
                                      icon: const Icon(Icons.edit),
                                    ),
                                  ),
                                );
                              }).toList(),
                              if (_enableLabelFlow) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text('标注队列', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _loading ? null : _loadLabelQueue,
                                  child: const Text('刷新队列'),
                                ),
                                const SizedBox(height: 8),
                                ..._labelNotes.map((n) {
                                  return Card(
                                    child: ListTile(
                                      title: Text('Note#${n.id} · ${n.cropType}'),
                                      subtitle: Text('status: ${n.labelStatus}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: _loading ? null : () => _labelNote(n),
                                            icon: const Icon(Icons.edit),
                                          ),
                                          IconButton(
                                            onPressed: _loading ? null : () => _reviewLabel(n, 'approved'),
                                            icon: const Icon(Icons.check, color: Colors.green),
                                          ),
                                          IconButton(
                                            onPressed: _loading ? null : () => _reviewLabel(n, 'rejected'),
                                            icon: const Icon(Icons.close, color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('评测汇总', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loading ? null : _loadEval,
                                child: const Text('刷新评测'),
                              ),
                              const SizedBox(height: 8),
                              if (_eval != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      title: Text('总样本 ${_eval!.total}，正确 ${_eval!.correct}'),
                                      subtitle: Text('准确率 ${(100 * _eval!.accuracy).toStringAsFixed(2)}%'),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('按作物准确率', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ..._eval!.byCrop.take(10).map((s) {
                                      return ListTile(
                                        dense: true,
                                        title: Text(s.cropType),
                                        subtitle: Text('样本 ${s.total} · 正确 ${s.correct}'),
                                        trailing: Text('${(100 * s.accuracy).toStringAsFixed(1)}%'),
                                      );
                                    }).toList(),
                                    if (_eval!.byCrop.length > 10)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 4),
                                        child: Text('仅显示前 10'),
                                      ),
                                    const SizedBox(height: 8),
                                    const Text('Top 混淆对', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ..._eval!.confusions.map((c) {
                                      return ListTile(
                                        dense: true,
                                        title: Text('${c.actual} -> ${c.predicted}'),
                                        trailing: Text('${c.count}'),
                                      );
                                    }).toList(),
                                  ],
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value) {
    return Chip(label: Text('$label: $value'));
  }
}
