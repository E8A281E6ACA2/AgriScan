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
  final _auditActionController = TextEditingController();
  final _auditTargetController = TextEditingController();
  final _auditStartController = TextEditingController();
  final _auditEndController = TextEditingController();
  final _labelBatchStatusController = TextEditingController(text: 'labeled');
  final _labelBatchCategoryController = TextEditingController();
  final _labelBatchCropController = TextEditingController();
  final _labelBatchStartController = TextEditingController();
  final _labelBatchEndController = TextEditingController();
  final _reqStatusController = TextEditingController(text: 'pending');
  final _quotaDeltaController = TextEditingController(text: '1000');
  final _quotaController = TextEditingController();
  final _usedController = TextEditingController();
  final _creditsController = TextEditingController();
  final _metricsDaysController = TextEditingController(text: '30');
  final _evalDaysController = TextEditingController(text: '30');
  final _qcDaysController = TextEditingController(text: '30');
  final _qcLowLimitController = TextEditingController(text: '50');
  final _qcRandomLimitController = TextEditingController(text: '30');
  final _qcFeedbackLimitController = TextEditingController(text: '20');
  final _qcThresholdController = TextEditingController(text: '0.5');
  final _qcStatusController = TextEditingController(text: 'pending');
  final _qcReasonController = TextEditingController();
  final _lowConfDaysController = TextEditingController(text: '30');
  final _lowConfLimitController = TextEditingController(text: '50');
  final _lowConfOffsetController = TextEditingController(text: '0');
  final _lowConfThresholdController = TextEditingController(text: '0.5');
  final _lowConfReasonController = TextEditingController(text: 'low_confidence');
  final _lowConfProviderController = TextEditingController();
  final _lowConfCropController = TextEditingController();
  final _lowConfStartController = TextEditingController();
  final _lowConfEndController = TextEditingController();
  final _failedDaysController = TextEditingController(text: '30');
  final _failedLimitController = TextEditingController(text: '50');
  final _failedOffsetController = TextEditingController(text: '0');
  final _failedReasonController = TextEditingController(text: 'failed');
  final _failedProviderController = TextEditingController();
  final _failedCropController = TextEditingController();
  final _failedStartController = TextEditingController();
  final _failedEndController = TextEditingController();
  final _evalSetNameController = TextEditingController(text: 'baseline-v1');
  final _evalSetDescController = TextEditingController();
  final _evalSetDaysController = TextEditingController(text: '30');
  final _evalSetLimitController = TextEditingController(text: '200');

  bool _loading = false;
  List<AdminUser> _users = [];
  List<EmailLog> _logs = [];
  List<MembershipRequest> _requests = [];
  List<AdminAuditLog> _audits = [];
  List<AdminLabelNote> _labelNotes = [];
  List<PlanSetting> _planSettings = [];
  List<AppSetting> _settings = [];
  List<EvalRun> _evalRuns = [];
  List<QCSample> _qcSamples = [];
  List<AdminResultItem> _lowConfResults = [];
  List<AdminResultItem> _failedResults = [];
  List<EvalSet> _evalSets = [];
  List<EvalSetRun> _evalSetRuns = [];
  EvalSet? _selectedEvalSet;
  final Set<int> _qcSelected = {};
  final Set<int> _lowConfSelected = {};
  final Set<int> _failedSelected = {};
  AdminStats? _stats;
  EvalSummary? _eval;
  AdminMetrics? _metrics;
  AdminUser? _selected;
  String _plan = 'free';
  String _status = 'active';
  bool _labelFlowEnabled = false;
  String _filterPlan = '';
  String _filterStatus = '';
  final List<_LabelTemplate> _labelTemplates = const [
    _LabelTemplate(label: '病害-锈病', category: 'disease', tags: ['锈病']),
    _LabelTemplate(label: '病害-白粉病', category: 'disease', tags: ['白粉病']),
    _LabelTemplate(label: '病害-叶斑病', category: 'disease', tags: ['叶斑病']),
    _LabelTemplate(label: '虫害-蚜虫', category: 'pest', tags: ['蚜虫']),
    _LabelTemplate(label: '虫害-螟虫', category: 'pest', tags: ['螟虫']),
    _LabelTemplate(label: '虫害-红蜘蛛', category: 'pest', tags: ['红蜘蛛']),
    _LabelTemplate(label: '杂草-稗草', category: 'weed', tags: ['稗草']),
    _LabelTemplate(label: '杂草-马齿苋', category: 'weed', tags: ['马齿苋']),
    _LabelTemplate(label: '正常', category: 'crop', tags: ['正常']),
    _LabelTemplate(label: '清空标签', category: '', tags: []),
  ];

  @override
  void dispose() {
    _tokenController.dispose();
    _searchController.dispose();
    _logEmailController.dispose();
    _auditActionController.dispose();
    _auditTargetController.dispose();
    _auditStartController.dispose();
    _auditEndController.dispose();
    _labelBatchStatusController.dispose();
    _labelBatchCategoryController.dispose();
    _labelBatchCropController.dispose();
    _labelBatchStartController.dispose();
    _labelBatchEndController.dispose();
    _reqStatusController.dispose();
    _quotaDeltaController.dispose();
    _quotaController.dispose();
    _usedController.dispose();
    _creditsController.dispose();
    _metricsDaysController.dispose();
    _evalDaysController.dispose();
    _qcDaysController.dispose();
    _qcLowLimitController.dispose();
    _qcRandomLimitController.dispose();
    _qcFeedbackLimitController.dispose();
    _qcThresholdController.dispose();
    _qcStatusController.dispose();
    _qcReasonController.dispose();
    _lowConfDaysController.dispose();
    _lowConfLimitController.dispose();
    _lowConfOffsetController.dispose();
    _lowConfThresholdController.dispose();
    _lowConfReasonController.dispose();
    _lowConfProviderController.dispose();
    _lowConfCropController.dispose();
    _lowConfStartController.dispose();
    _lowConfEndController.dispose();
    _failedDaysController.dispose();
    _failedLimitController.dispose();
    _failedOffsetController.dispose();
    _failedReasonController.dispose();
    _failedProviderController.dispose();
    _failedCropController.dispose();
    _failedStartController.dispose();
    _failedEndController.dispose();
    _evalSetNameController.dispose();
    _evalSetDescController.dispose();
    _evalSetDaysController.dispose();
    _evalSetLimitController.dispose();
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
        plan: _filterPlan,
        status: _filterStatus,
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

  Future<void> _loadMetrics() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final days = int.tryParse(_metricsDaysController.text) ?? 30;
    setState(() => _loading = true);
    try {
      final metrics = await api.adminMetrics(days: days, adminToken: token.isEmpty ? null : token);
      if (mounted) setState(() => _metrics = metrics);
    } catch (e) {
      _toast('指标加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      final items = await api.adminAuditLogs(
        action: _auditActionController.text.trim(),
        targetType: _auditTargetController.text.trim(),
        startDate: _auditStartController.text.trim(),
        endDate: _auditEndController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
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

  Future<void> _loadSettings() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final items = await api.adminSettings(adminToken: token.isEmpty ? null : token);
      final labelOn = items.any((s) => s.key == 'label_flow_enabled' && _isTrue(s.value));
      setState(() {
        _settings = items;
        _labelFlowEnabled = labelOn;
      });
    } catch (e) {
      _toast('系统配置失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editSetting(AppSetting setting) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    dynamic newValue = setting.value;
    final controller = TextEditingController(text: setting.value);
    bool boolValue = setting.value.toLowerCase() == 'true' || setting.value == '1';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('编辑 ${setting.key}'),
          content: setting.type == 'bool'
              ? StatefulBuilder(
                  builder: (context, setState) {
                    return SwitchListTile(
                      value: boolValue,
                      onChanged: (v) => setState(() => boolValue = v),
                      title: Text(setting.description.isEmpty ? setting.key : setting.description),
                    );
                  },
                )
              : TextField(
                  controller: controller,
                  decoration: InputDecoration(labelText: setting.description),
                  keyboardType: setting.type == 'int' ? TextInputType.number : TextInputType.text,
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        );
      },
    );
    if (ok != true) return;
    if (setting.type == 'bool') {
      newValue = boolValue;
    } else {
      newValue = controller.text.trim();
    }
    setState(() => _loading = true);
    try {
      await api.adminUpdateSetting(
        setting.key,
        AppSettingUpdate(value: newValue),
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已保存');
      await _loadSettings();
    } catch (e) {
      _toast('保存失败: $e');
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
    final priceController = TextEditingController(text: plan.priceCents.toString());
    final billingController = TextEditingController(text: plan.billingUnit);
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
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: '价格(分)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: billingController,
                  decoration: const InputDecoration(labelText: '计费周期(month/year/once)'),
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
          priceCents: int.tryParse(priceController.text.trim()),
          billingUnit: billingController.text.trim(),
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

  Future<void> _loadEvalRuns() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final items = await api.adminEvalRuns(adminToken: token.isEmpty ? null : token);
      setState(() => _evalRuns = items);
    } catch (e) {
      _toast('评测快照失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateQCSamples() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final days = int.tryParse(_qcDaysController.text) ?? 30;
    final lowLimit = int.tryParse(_qcLowLimitController.text) ?? 0;
    final randomLimit = int.tryParse(_qcRandomLimitController.text) ?? 0;
    final feedbackLimit = int.tryParse(_qcFeedbackLimitController.text) ?? 0;
    final threshold = double.tryParse(_qcThresholdController.text) ?? 0.5;
    setState(() => _loading = true);
    try {
      final res = await api.adminGenerateQCSamples(
        days: days,
        lowLimit: lowLimit,
        randomLimit: randomLimit,
        feedbackLimit: feedbackLimit,
        lowConfThreshold: threshold,
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已生成 ${res.created}/${res.requested}');
      await _loadQCSamples();
    } catch (e) {
      _toast('生成失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQCSamples() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final items = await api.adminListQCSamples(
        status: _qcStatusController.text.trim(),
        reason: _qcReasonController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      setState(() => _qcSamples = items);
    } catch (e) {
      _toast('质检列表失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reviewQCSample(QCSample sample, String status) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      await api.adminReviewQCSample(
        sample.id,
        status: status,
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已更新');
      await _loadQCSamples();
    } catch (e) {
      _toast('更新失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _batchReviewQCSamples(String status) async {
    if (_qcSelected.isEmpty) {
      _toast('请选择样本');
      return;
    }
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final updated = await api.adminBatchReviewQCSamples(
        ids: _qcSelected.toList(),
        status: status,
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已更新 $updated 条');
      _qcSelected.clear();
      await _loadQCSamples();
    } catch (e) {
      _toast('批量更新失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportQCSamples(String format) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportQCSamples(
        format: format,
        status: _qcStatusController.text.trim(),
        reason: _qcReasonController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      final name = format == 'json' ? 'qc_samples.json' : 'qc_samples.csv';
      final path = await saveBytesAsFile(name, bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
    }
  }

  Future<void> _loadLowConfidenceResults({bool append = false}) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final days = int.tryParse(_lowConfDaysController.text) ?? 30;
    final limit = int.tryParse(_lowConfLimitController.text) ?? 50;
    final offset = int.tryParse(_lowConfOffsetController.text) ?? 0;
    final nextOffset = append ? offset + limit : offset;
    final threshold = double.tryParse(_lowConfThresholdController.text) ?? 0.5;
    setState(() => _loading = true);
    try {
      final items = await api.adminLowConfidenceResults(
        days: days,
        limit: limit,
        offset: nextOffset,
        threshold: threshold,
        provider: _lowConfProviderController.text.trim(),
        cropType: _lowConfCropController.text.trim(),
        startDate: _lowConfStartController.text.trim(),
        endDate: _lowConfEndController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      setState(() {
        if (append) {
          if (items.isEmpty) {
            _toast('没有更多结果');
          } else {
            _lowConfResults = [..._lowConfResults, ...items];
            _lowConfOffsetController.text = nextOffset.toString();
          }
        } else {
          _lowConfResults = items;
          _lowConfOffsetController.text = nextOffset.toString();
        }
        _lowConfSelected.clear();
      });
    } catch (e) {
      _toast('低置信度列表失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFailedResults({bool append = false}) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final days = int.tryParse(_failedDaysController.text) ?? 30;
    final limit = int.tryParse(_failedLimitController.text) ?? 50;
    final offset = int.tryParse(_failedOffsetController.text) ?? 0;
    final nextOffset = append ? offset + limit : offset;
    setState(() => _loading = true);
    try {
      final items = await api.adminFailedResults(
        days: days,
        limit: limit,
        offset: nextOffset,
        provider: _failedProviderController.text.trim(),
        cropType: _failedCropController.text.trim(),
        startDate: _failedStartController.text.trim(),
        endDate: _failedEndController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      setState(() {
        if (append) {
          if (items.isEmpty) {
            _toast('没有更多结果');
          } else {
            _failedResults = [..._failedResults, ...items];
            _failedOffsetController.text = nextOffset.toString();
          }
        } else {
          _failedResults = items;
          _failedOffsetController.text = nextOffset.toString();
        }
        _failedSelected.clear();
      });
    } catch (e) {
      _toast('失败结果列表失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportLowConfidenceResults(String format) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportLowConfidenceResults(
        format: format,
        days: int.tryParse(_lowConfDaysController.text) ?? 30,
        threshold: double.tryParse(_lowConfThresholdController.text) ?? 0.5,
        provider: _lowConfProviderController.text.trim(),
        cropType: _lowConfCropController.text.trim(),
        startDate: _lowConfStartController.text.trim(),
        endDate: _lowConfEndController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      final name = format == 'json' ? 'low_confidence_results.json' : 'low_confidence_results.csv';
      final path = await saveBytesAsFile(name, bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
    }
  }

  Future<void> _exportFailedResults(String format) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportFailedResults(
        format: format,
        days: int.tryParse(_failedDaysController.text) ?? 30,
        provider: _failedProviderController.text.trim(),
        cropType: _failedCropController.text.trim(),
        startDate: _failedStartController.text.trim(),
        endDate: _failedEndController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      final name = format == 'json' ? 'failed_results.json' : 'failed_results.csv';
      final path = await saveBytesAsFile(name, bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
    }
  }

  Future<void> _addLowConfToQC() async {
    if (_lowConfSelected.isEmpty) {
      _toast('请选择结果');
      return;
    }
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final reason = _lowConfReasonController.text.trim();
    setState(() => _loading = true);
    try {
      final created = await api.adminCreateQCSamplesFromResults(
        ids: _lowConfSelected.toList(),
        reason: reason,
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已加入质检 $created 条');
      _lowConfSelected.clear();
      await _loadQCSamples();
    } catch (e) {
      _toast('加入质检失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addFailedToQC() async {
    if (_failedSelected.isEmpty) {
      _toast('请选择结果');
      return;
    }
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final reason = _failedReasonController.text.trim();
    setState(() => _loading = true);
    try {
      final created = await api.adminCreateQCSamplesFromResults(
        ids: _failedSelected.toList(),
        reason: reason,
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已加入质检 $created 条');
      _failedSelected.clear();
      await _loadQCSamples();
    } catch (e) {
      _toast('加入质检失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleLowConfResult(int id, bool selected) {
    setState(() {
      if (selected) {
        _lowConfSelected.add(id);
      } else {
        _lowConfSelected.remove(id);
      }
    });
  }

  void _toggleFailedResult(int id, bool selected) {
    setState(() {
      if (selected) {
        _failedSelected.add(id);
      } else {
        _failedSelected.remove(id);
      }
    });
  }

  void _showResultDetail(AdminResultItem item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Result#${item.resultId}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.imageUrl.isNotEmpty)
                  Image.network(item.imageUrl, height: 180, fit: BoxFit.cover)
                else
                  const Text('无图片地址'),
                const SizedBox(height: 8),
                Text('作物: ${item.cropType.isEmpty ? "未识别" : item.cropType}'),
                Text('置信度: ${item.confidence.toStringAsFixed(2)}'),
                Text('来源: ${item.provider}'),
                Text('时间: ${item.createdAt}'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          ],
        );
      },
    );
  }

  void _toggleQCSample(int id, bool selected) {
    setState(() {
      if (selected) {
        _qcSelected.add(id);
      } else {
        _qcSelected.remove(id);
      }
    });
  }

  void _showQCSampleDetail(QCSample sample) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Result#${sample.resultId}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sample.imageUrl.isNotEmpty)
                  Image.network(sample.imageUrl, height: 180, fit: BoxFit.cover)
                else
                  const Text('无图片地址'),
                const SizedBox(height: 8),
                Text('作物: ${sample.cropType}'),
                Text('置信度: ${sample.confidence.toStringAsFixed(2)}'),
                Text('来源: ${sample.provider}'),
                Text('原因: ${sample.reason}'),
                Text('状态: ${sample.status}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _labelQCSample(sample);
              },
              child: const Text('回写标注'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          ],
        );
      },
    );
  }

  Widget _buildLabelTemplateChips({
    required TextEditingController categoryController,
    required TextEditingController tagsController,
    required TextEditingController noteController,
  }) {
    void applyTemplate(_LabelTemplate tpl) {
      if (tpl.category.isNotEmpty) {
        categoryController.text = tpl.category;
      }
      if (tpl.label == '清空标签') {
        tagsController.text = '';
        return;
      }
      final existing = tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final merged = <String>[];
      final seen = <String>{};
      for (final t in [...existing, ...tpl.tags]) {
        if (t.isEmpty || seen.contains(t)) continue;
        seen.add(t);
        merged.add(t);
      }
      tagsController.text = merged.join(',');
      if (tpl.note.isNotEmpty && noteController.text.trim().isEmpty) {
        noteController.text = tpl.note;
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _labelTemplates
          .map((tpl) => OutlinedButton(
                onPressed: () => applyTemplate(tpl),
                child: Text(tpl.label),
              ))
          .toList(),
    );
  }

  Future<void> _labelQCSample(QCSample sample) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final categoryController = TextEditingController();
    final cropController = TextEditingController(text: sample.cropType);
    final tagsController = TextEditingController();
    final noteController = TextEditingController();
    bool approved = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('回写标注'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLabelTemplateChips(
                  categoryController: categoryController,
                  tagsController: tagsController,
                  noteController: noteController,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: '类别(可选)'),
                ),
                TextField(
                  controller: cropController,
                  decoration: const InputDecoration(labelText: '作物/对象'),
                ),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(labelText: '标签(逗号)'),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (context, setState) {
                    return CheckboxListTile(
                      value: approved,
                      onChanged: (v) => setState(() => approved = v ?? true),
                      title: const Text('直接通过'),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('提交')),
          ],
        );
      },
    );
    if (ok != true) return;
    final crop = cropController.text.trim();
    if (crop.isEmpty) {
      _toast('请填写作物/对象');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await api.adminLabelQCSample(
        sample.id,
        category: categoryController.text.trim(),
        cropType: crop,
        tags: tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        note: noteController.text.trim(),
        approved: approved,
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已回写(${res.status})');
      await _loadQCSamples();
      if (_labelFlowEnabled) {
        await _loadLabelQueue();
      }
      await _loadEval();
    } catch (e) {
      _toast('回写失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createEvalRun() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final days = int.tryParse(_evalDaysController.text) ?? 30;
    setState(() => _loading = true);
    try {
      await api.adminCreateEvalRun(days: days, adminToken: token.isEmpty ? null : token);
      _toast('已生成');
      await _loadEvalRuns();
      await _loadEval();
    } catch (e) {
      _toast('生成失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEvalSets() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final items = await api.adminEvalSets(adminToken: token.isEmpty ? null : token);
      setState(() => _evalSets = items);
    } catch (e) {
      _toast('评测集失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createEvalSet() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final name = _evalSetNameController.text.trim();
    final desc = _evalSetDescController.text.trim();
    final days = int.tryParse(_evalSetDaysController.text) ?? 30;
    final limit = int.tryParse(_evalSetLimitController.text) ?? 200;
    setState(() => _loading = true);
    try {
      final item = await api.adminCreateEvalSet(
        name: name,
        description: desc,
        days: days,
        limit: limit,
        adminToken: token.isEmpty ? null : token,
      );
      _toast('已创建 ${item.id}');
      await _loadEvalSets();
    } catch (e) {
      _toast('创建失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEvalSetRuns(EvalSet set) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final items = await api.adminEvalSetRuns(set.id, adminToken: token.isEmpty ? null : token);
      setState(() {
        _selectedEvalSet = set;
        _evalSetRuns = items;
      });
    } catch (e) {
      _toast('评测集运行失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runEvalSet(EvalSet set) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      await api.adminRunEvalSet(set.id, adminToken: token.isEmpty ? null : token);
      _toast('已运行');
      await _loadEvalSetRuns(set);
    } catch (e) {
      _toast('运行失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportEvalSet(EvalSet set, String format) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportEvalSet(set.id, format: format, adminToken: token.isEmpty ? null : token);
      final name = format == 'json' ? 'eval_set_${set.id}.json' : 'eval_set_${set.id}.csv';
      final path = await saveBytesAsFile(name, bytes);
      _toast('导出成功: $path');
    } catch (e) {
      _toast('导出失败: $e');
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

  Future<void> _exportAuditLogs(String format) async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    try {
      final bytes = await api.adminExportAuditLogs(
        format: format,
        action: _auditActionController.text.trim(),
        targetType: _auditTargetController.text.trim(),
        startDate: _auditStartController.text.trim(),
        endDate: _auditEndController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      final name = format == 'json' ? 'audit_logs.json' : 'audit_logs.csv';
      final path = await saveBytesAsFile(name, bytes);
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
              _buildLabelTemplateChips(
                categoryController: categoryController,
                tagsController: tagsController,
                noteController: noteController,
              ),
              const SizedBox(height: 8),
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

  Future<void> _batchApproveLabels() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    setState(() => _loading = true);
    try {
      final updated = await api.adminBatchApproveLabels(
        status: _labelBatchStatusController.text.trim().isEmpty ? 'labeled' : _labelBatchStatusController.text.trim(),
        category: _labelBatchCategoryController.text.trim(),
        cropType: _labelBatchCropController.text.trim(),
        startDate: _labelBatchStartController.text.trim(),
        endDate: _labelBatchEndController.text.trim(),
        adminToken: token.isEmpty ? null : token,
      );
      _toast('批量通过 $updated 条');
      await _loadLabelQueue();
      await _loadEval();
    } catch (e) {
      _toast('批量通过失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                      _statChip('真实用户', _stats!.usersReal),
                      _statChip('游客', _stats!.usersGuest),
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
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('运营指标', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _metricsDaysController,
                            decoration: const InputDecoration(labelText: '天数'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _loading ? null : _loadMetrics,
                          child: const Text('刷新指标'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_metrics != null) ...[
                      Text('反馈正确率 ${(100 * _metrics!.feedbackAccuracy).toStringAsFixed(2)}%'),
                      Text(
                        '低置信度占比 ${(100 * _metrics!.lowConfidenceRatio).toStringAsFixed(2)}% (阈值 ${_metrics!.lowConfidenceThreshold})',
                      ),
                      const SizedBox(height: 8),
                      const Text('近况(识别次数/天)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: _metrics!.resultsByDay.map((d) => Chip(label: Text('${d.day}:${d.count}'))).toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text('用户分布', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: _metrics!.usersByPlan.map((n) => Chip(label: Text('${n.name}:${n.count}'))).toList(),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: _metrics!.usersByStatus.map((n) => Chip(label: Text('${n.name}:${n.count}'))).toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text('识别提供商', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      ..._metrics!.resultsByProvider.map((n) => Text('${n.name}: ${n.count}')).toList(),
                      const SizedBox(height: 8),
                      const Text('识别作物 Top', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      ..._metrics!.resultsByCrop.map((n) => Text('${n.name}: ${n.count}')).toList(),
                    ],
                  ],
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    value: _filterPlan,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('全部档次')),
                      DropdownMenuItem(value: 'free', child: Text('free')),
                      DropdownMenuItem(value: 'silver', child: Text('silver')),
                      DropdownMenuItem(value: 'gold', child: Text('gold')),
                      DropdownMenuItem(value: 'diamond', child: Text('diamond')),
                    ],
                    onChanged: (v) => setState(() => _filterPlan = v ?? ''),
                    decoration: const InputDecoration(labelText: '档次'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('全部状态')),
                      DropdownMenuItem(value: 'active', child: Text('active')),
                      DropdownMenuItem(value: 'guest', child: Text('guest')),
                      DropdownMenuItem(value: 'disabled', child: Text('disabled')),
                    ],
                    onChanged: (v) => setState(() => _filterStatus = v ?? ''),
                    decoration: const InputDecoration(labelText: '状态'),
                  ),
                ),
                const SizedBox(width: 8),
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _auditActionController,
                                      decoration: const InputDecoration(labelText: '动作(action)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _auditTargetController,
                                      decoration: const InputDecoration(labelText: '目标类型(target_type)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _auditStartController,
                                      decoration: const InputDecoration(labelText: '开始日期(YYYY-MM-DD)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _auditEndController,
                                      decoration: const InputDecoration(labelText: '结束日期(YYYY-MM-DD)'),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _loadAuditLogs,
                                    child: const Text('刷新审计'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _exportAuditLogs('csv'),
                                    child: const Text('导出CSV'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _exportAuditLogs('json'),
                                    child: const Text('导出JSON'),
                                  ),
                                ],
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
                              const Text('系统配置', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loading ? null : _loadSettings,
                                child: const Text('刷新配置'),
                              ),
                              const SizedBox(height: 8),
                              ..._settings.map((s) {
                                final value = s.type == 'bool'
                                    ? (s.value.toLowerCase() == 'true' || s.value == '1' ? '是' : '否')
                                    : s.value;
                                return Card(
                                  child: ListTile(
                                    title: Text(s.description.isEmpty ? s.key : s.description),
                                    subtitle: Text('key: ${s.key}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(value),
                                        IconButton(
                                          onPressed: _loading ? null : () => _editSetting(s),
                                          icon: const Icon(Icons.edit),
                                        ),
                                      ],
                                    ),
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
                                final price = p.priceCents <= 0
                                    ? '免费'
                                    : '¥${(p.priceCents / 100).toStringAsFixed(0)}/${p.billingUnit}';
                                return Card(
                                  child: ListTile(
                                    title: Text('${p.code} · ${p.name}'),
                                    subtitle: Text(
                                      '额度 ${p.quotaTotal} · 留存 ${p.retentionDays} 天 · 广告 ${p.requireAd ? "是" : "否"} · $price',
                                    ),
                                    trailing: IconButton(
                                      onPressed: _loading ? null : () => _editPlanSetting(p),
                                      icon: const Icon(Icons.edit),
                                    ),
                                  ),
                                );
                              }).toList(),
                              if (_labelFlowEnabled) ...[
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
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: TextField(
                                        controller: _labelBatchStatusController,
                                        decoration: const InputDecoration(labelText: '状态(labeled/pending)'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: TextField(
                                        controller: _labelBatchCategoryController,
                                        decoration: const InputDecoration(labelText: '类别(可选)'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: TextField(
                                        controller: _labelBatchCropController,
                                        decoration: const InputDecoration(labelText: '作物(可选)'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 160,
                                      child: TextField(
                                        controller: _labelBatchStartController,
                                        decoration: const InputDecoration(labelText: '开始日期(YYYY-MM-DD)'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 160,
                                      child: TextField(
                                        controller: _labelBatchEndController,
                                        decoration: const InputDecoration(labelText: '结束日期(YYYY-MM-DD)'),
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: _loading ? null : _batchApproveLabels,
                                      child: const Text('批量通过已标注'),
                                    ),
                                  ],
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
                              const Text('低置信度结果', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _lowConfDaysController,
                                      decoration: const InputDecoration(labelText: '天数'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _lowConfThresholdController,
                                      decoration: const InputDecoration(labelText: '阈值'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _lowConfProviderController,
                                      decoration: const InputDecoration(labelText: '提供商(可选)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _lowConfCropController,
                                      decoration: const InputDecoration(labelText: '作物(可选)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _lowConfStartController,
                                      decoration: const InputDecoration(labelText: '开始日期(YYYY-MM-DD)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _lowConfEndController,
                                      decoration: const InputDecoration(labelText: '结束日期(YYYY-MM-DD)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _lowConfLimitController,
                                      decoration: const InputDecoration(labelText: '数量'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _lowConfOffsetController,
                                      decoration: const InputDecoration(labelText: '偏移'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _lowConfReasonController,
                                      decoration: const InputDecoration(labelText: '质检原因'),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _loadLowConfidenceResults,
                                    child: const Text('刷新列表'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _loadLowConfidenceResults(append: true),
                                    child: const Text('加载更多'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _exportLowConfidenceResults('csv'),
                                    child: const Text('导出CSV'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _exportLowConfidenceResults('json'),
                                    child: const Text('导出JSON'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : _addLowConfToQC,
                                    child: const Text('加入质检'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._lowConfResults.map((r) {
                                final selected = _lowConfSelected.contains(r.resultId);
                                final title = r.cropType.isEmpty ? '未识别' : r.cropType;
                                final subtitle =
                                    '${r.createdAt} | conf ${r.confidence.toStringAsFixed(2)} | ${r.provider}';
                                return Card(
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: selected,
                                      onChanged: (v) => _toggleLowConfResult(r.resultId, v ?? false),
                                    ),
                                    title: Text('Result#${r.resultId} · $title'),
                                    subtitle: Text(subtitle),
                                    trailing: r.imageUrl.isNotEmpty
                                        ? SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Image.network(r.imageUrl, fit: BoxFit.cover),
                                          )
                                        : null,
                                    onTap: () => _showResultDetail(r),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('失败结果', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _failedDaysController,
                                      decoration: const InputDecoration(labelText: '天数'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _failedLimitController,
                                      decoration: const InputDecoration(labelText: '数量'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _failedProviderController,
                                      decoration: const InputDecoration(labelText: '提供商(可选)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _failedCropController,
                                      decoration: const InputDecoration(labelText: '作物(可选)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _failedStartController,
                                      decoration: const InputDecoration(labelText: '开始日期(YYYY-MM-DD)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _failedEndController,
                                      decoration: const InputDecoration(labelText: '结束日期(YYYY-MM-DD)'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _failedOffsetController,
                                      decoration: const InputDecoration(labelText: '偏移'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _failedReasonController,
                                      decoration: const InputDecoration(labelText: '质检原因'),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _loadFailedResults,
                                    child: const Text('刷新列表'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _loadFailedResults(append: true),
                                    child: const Text('加载更多'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _exportFailedResults('csv'),
                                    child: const Text('导出CSV'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _exportFailedResults('json'),
                                    child: const Text('导出JSON'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : _addFailedToQC,
                                    child: const Text('加入质检'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._failedResults.map((r) {
                                final selected = _failedSelected.contains(r.resultId);
                                final title = r.cropType.isEmpty ? '未识别' : r.cropType;
                                final subtitle =
                                    '${r.createdAt} | conf ${r.confidence.toStringAsFixed(2)} | ${r.provider}';
                                return Card(
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: selected,
                                      onChanged: (v) => _toggleFailedResult(r.resultId, v ?? false),
                                    ),
                                    title: Text('Result#${r.resultId} · $title'),
                                    subtitle: Text(subtitle),
                                    trailing: r.imageUrl.isNotEmpty
                                        ? SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Image.network(r.imageUrl, fit: BoxFit.cover),
                                          )
                                        : null,
                                    onTap: () => _showResultDetail(r),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('质检样本', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _qcDaysController,
                                      decoration: const InputDecoration(labelText: '天数'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _qcLowLimitController,
                                      decoration: const InputDecoration(labelText: '低置信度'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _qcRandomLimitController,
                                      decoration: const InputDecoration(labelText: '随机数'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _qcFeedbackLimitController,
                                      decoration: const InputDecoration(labelText: '反馈数'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _qcThresholdController,
                                      decoration: const InputDecoration(labelText: '阈值'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _generateQCSamples,
                                    child: const Text('生成样本'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : _loadQCSamples,
                                    child: const Text('刷新列表'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _exportQCSamples('csv'),
                                    child: const Text('导出CSV'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _exportQCSamples('json'),
                                    child: const Text('导出JSON'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _batchReviewQCSamples('keep'),
                                    child: const Text('批量保留'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : () => _batchReviewQCSamples('discard'),
                                    child: const Text('批量剔除'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _qcStatusController,
                                      decoration: const InputDecoration(labelText: '状态(pending/keep/discard)'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _qcReasonController,
                                      decoration: const InputDecoration(labelText: '原因(可选)'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._qcSamples.map((s) {
                                final selected = _qcSelected.contains(s.id);
                                return Card(
                                  child: ListTile(
                                    title: Text('Result#${s.resultId} · ${s.cropType} · ${s.confidence.toStringAsFixed(2)}'),
                                    subtitle: Text('${s.reason} · ${s.status}'),
                                    leading: Checkbox(
                                      value: selected,
                                      onChanged: (v) => _toggleQCSample(s.id, v ?? false),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: _loading ? null : () => _reviewQCSample(s, 'keep'),
                                          icon: const Icon(Icons.check, color: Colors.green),
                                        ),
                                        IconButton(
                                          onPressed: _loading ? null : () => _reviewQCSample(s, 'discard'),
                                          icon: const Icon(Icons.close, color: Colors.red),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showQCSampleDetail(s),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('评测集', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _evalSetNameController,
                                      decoration: const InputDecoration(labelText: '名称'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 200,
                                    child: TextField(
                                      controller: _evalSetDescController,
                                      decoration: const InputDecoration(labelText: '描述'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _evalSetDaysController,
                                      decoration: const InputDecoration(labelText: '天数'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _evalSetLimitController,
                                      decoration: const InputDecoration(labelText: '数量'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _createEvalSet,
                                    child: const Text('创建评测集'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _loading ? null : _loadEvalSets,
                                    child: const Text('刷新评测集'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._evalSets.map((s) {
                                return Card(
                                  child: ListTile(
                                    title: Text('${s.name} (#${s.id})'),
                                    subtitle: Text('size ${s.size} · ${s.createdAt}'),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        TextButton(
                                          onPressed: _loading ? null : () => _runEvalSet(s),
                                          child: const Text('运行'),
                                        ),
                                        TextButton(
                                          onPressed: _loading ? null : () => _loadEvalSetRuns(s),
                                          child: const Text('查看'),
                                        ),
                                        IconButton(
                                          onPressed: _loading ? null : () => _exportEvalSet(s, 'csv'),
                                          icon: const Icon(Icons.download),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              if (_selectedEvalSet != null && _evalSetRuns.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('评测集运行：${_selectedEvalSet!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                ..._evalSetRuns.map((r) {
                                  final delta = (100 * r.deltaAcc).toStringAsFixed(2);
                                  return ListTile(
                                    dense: true,
                                    title: Text('Run#${r.id} · ${r.createdAt}'),
                                    subtitle: Text('total ${r.total} · correct ${r.correct}'),
                                    trailing: Text('${(100 * r.accuracy).toStringAsFixed(2)}% (Δ ${delta}%)'),
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
                              const SizedBox(height: 12),
                              const Text('评测快照', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _evalDaysController,
                                      decoration: const InputDecoration(labelText: '天数'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _createEvalRun,
                                    child: const Text('生成快照'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _loading ? null : _loadEvalRuns,
                                    child: const Text('刷新快照'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._evalRuns.map((r) {
                                return ListTile(
                                  dense: true,
                                  title: Text('Run#${r.id} · ${r.createdAt}'),
                                  subtitle: Text('days ${r.days} · total ${r.total} · correct ${r.correct}'),
                                  trailing: Text('${(100 * r.accuracy).toStringAsFixed(2)}%'),
                                );
                              }).toList(),
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

  bool _isTrue(String value) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1';
  }
}

class _LabelTemplate {
  final String label;
  final String category;
  final List<String> tags;
  final String note;

  const _LabelTemplate({
    required this.label,
    required this.category,
    required this.tags,
    this.note = '',
  });
}
