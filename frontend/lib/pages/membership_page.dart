import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../utils/auth_flow.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  bool _loading = false;
  Entitlements? _ent;
  List<PlanSetting> _plans = [];
  final TextEditingController _noteController = TextEditingController();

  Future<void> _load() async {
    final api = context.read<ApiService>();
    setState(() => _loading = true);
    try {
      final ent = await api.getEntitlements();
      final plans = await api.getPlans();
      setState(() {
        _ent = ent;
        _plans = plans;
      });
    } catch (e) {
      _toast('获取权益失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recommended = _recommendedPlan();
    return Scaffold(
      appBar: AppBar(
        title: const Text('会员权益'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ent == null
              ? const Center(child: Text('暂无权益信息'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (recommended != null) ...[
                      _buildQuickApplyCard(recommended),
                      const SizedBox(height: 12),
                    ],
                    ..._buildPlanCards(),
                    const Divider(height: 24),
                    _buildTile('档次', _formatPlanLabel(_ent!)),
                    _buildTile('需要登录', _ent!.requireLogin ? '是' : '否'),
                    _buildTile('需要广告', _ent!.requireAd ? '是' : '否'),
                    _buildTile('广告次数余额', _ent!.adCredits.toString()),
                    _buildTile('额度总数', _ent!.quotaTotal.toString()),
                    _buildTile('已用额度', _ent!.quotaUsed.toString()),
                    _buildTile('剩余额度', _ent!.quotaRemaining.toString()),
                    _buildTile('匿名剩余次数', _ent!.anonymousRemaining.toString()),
                    _buildTile('数据留存天数', _ent!.retentionDays.toString()),
                  ],
                ),
    );
  }

  List<Widget> _buildPlanCards() {
    final paidPlans = _plans.where((p) => p.code != 'free').toList();
    final plans = paidPlans.isEmpty ? _defaultPlans() : paidPlans;
    final widgets = <Widget>[];
    for (var i = 0; i < plans.length; i++) {
      widgets.add(_buildPlanCard(plans[i]));
      if (i != plans.length - 1) {
        widgets.add(const SizedBox(height: 8));
      }
    }
    return widgets;
  }

  List<PlanSetting> _defaultPlans() {
    return [
      PlanSetting(
        code: 'silver',
        name: '白银',
        description: '适合频繁识别',
        quotaTotal: 5000,
        retentionDays: 90,
        requireAd: false,
        priceCents: 9900,
        billingUnit: 'month',
      ),
      PlanSetting(
        code: 'gold',
        name: '黄金',
        description: '更高额度',
        quotaTotal: 20000,
        retentionDays: 180,
        requireAd: false,
        priceCents: 19900,
        billingUnit: 'month',
      ),
      PlanSetting(
        code: 'diamond',
        name: '钻石',
        description: '最高额度',
        quotaTotal: 100000,
        retentionDays: 365,
        requireAd: false,
        priceCents: 39900,
        billingUnit: 'month',
      ),
    ];
  }

  PlanSetting? _recommendedPlan() {
    final paidPlans = _plans.where((p) => p.code != 'free').toList();
    final plans = paidPlans.isEmpty ? _defaultPlans() : paidPlans;
    if (plans.isEmpty) return null;
    if (plans.length == 1) return plans.first;
    plans.sort((a, b) => a.priceCents.compareTo(b.priceCents));
    return plans[(plans.length / 2).floor()];
  }

  Widget _buildTile(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(value),
    );
  }

  Widget _buildQuickApplyCard(PlanSetting plan) {
    final isCurrent = _ent?.plan == plan.code;
    return Card(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('推荐方案', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${plan.name}档 · ${plan.description}'),
                  const SizedBox(height: 4),
                  Text(
                    '额度 ${plan.quotaTotal} · 留存 ${plan.retentionDays} 天'
                    '${plan.requireAd ? ' · 需广告' : ''} · ${_formatPrice(plan)}',
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isCurrent ? null : () => _onApplyPlan(plan),
              child: Text(isCurrent ? '当前' : '一键申请'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(PlanSetting plan) {
    final isCurrent = _ent?.plan == plan.code;
    final adLabel = plan.requireAd ? ' · 需广告' : '';
    return Card(
      child: ListTile(
        title: Text('${plan.name}档', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${plan.description} · ${plan.quotaTotal} 次额度 · 留存 ${plan.retentionDays} 天$adLabel · ${_formatPrice(plan)}',
        ),
        trailing: isCurrent
            ? const Chip(label: Text('当前'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _onApplyPlan(plan),
                    child: const Text('申请升级'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => _onCheckoutPlan(plan),
                    child: const Text('立即购买'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onApplyPlan(PlanSetting plan) async {
    final ok = await _confirmPlanAction(plan, '申请升级');
    if (!ok) return;
    await _requestUpgrade(plan.code);
  }

  Future<void> _onCheckoutPlan(PlanSetting plan) async {
    final ok = await _confirmPlanAction(plan, '立即购买');
    if (!ok) return;
    await _checkout(plan.code);
  }

  Future<bool> _confirmPlanAction(PlanSetting plan, String actionLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认$actionLabel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${plan.name}档 · ${plan.description}'),
              const SizedBox(height: 8),
              Text('额度：${plan.quotaTotal}'),
              Text('留存：${plan.retentionDays} 天'),
              Text('价格：${_formatPrice(plan)}'),
              if (plan.requireAd) const Text('需要观看广告'),
              const SizedBox(height: 8),
              const Text('确认后将跳转到支付页面。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _requestUpgrade(String plan) async {
    final api = context.read<ApiService>();
    final ok = await _ensureLogin(api);
    if (!ok) return;
    final note = await _promptNote();
    if (note == null) return;
    try {
      await api.createMembershipRequest(plan: plan, note: note);
      _toast('已提交申请');
    } catch (e) {
      _toast('提交失败: $e');
    }
  }

  Future<void> _checkout(String plan) async {
    final api = context.read<ApiService>();
    final ok = await _ensureLogin(api);
    if (!ok) return;
    try {
      final res = await api.paymentCheckout(plan: plan, method: 'stripe');
      if (res.checkoutUrl.isEmpty) {
        _toast('支付链接为空，请稍后重试');
        return;
      }
      await _openCheckoutUrl(res.checkoutUrl);
    } catch (e) {
      _toast('发起支付失败: $e');
    }
  }

  Future<bool> _ensureLogin(ApiService api) async {
    if (_ent != null && _ent!.userId > 0) {
      return true;
    }
    final ok = await startLoginFlow(context, api);
    if (ok) {
      await _load();
    }
    return ok;
  }

  String _formatPrice(PlanSetting plan) {
    if (plan.priceCents <= 0) {
      return '免费';
    }
    final amount = (plan.priceCents / 100).toStringAsFixed(0);
    final unit = plan.billingUnit.isEmpty ? 'month' : plan.billingUnit;
    return '¥$amount/$unit';
  }

  String _formatPlanLabel(Entitlements ent) {
    if (ent.planName.isEmpty) return ent.plan;
    if (ent.planName == ent.plan) return ent.planName;
    return '${ent.planName} (${ent.plan})';
  }

  Future<void> _openCheckoutUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast('支付链接无效');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _toast('打开支付链接失败');
    }
  }

  Future<String?> _promptNote() async {
    _noteController.text = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('申请升级'),
          content: TextField(
            controller: _noteController,
            decoration: const InputDecoration(hintText: '补充说明（可选）'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _noteController.text.trim()),
              child: const Text('提交'),
            ),
          ],
        );
      },
    );
    return result;
  }
}
