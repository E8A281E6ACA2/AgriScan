import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';

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
                    ..._buildPlanCards(),
                    const Divider(height: 24),
                    _buildTile('档次', _ent!.plan),
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
    if (paidPlans.isEmpty) {
      return [
        _buildPlanCard(PlanSetting(
          code: 'silver',
          name: '白银',
          description: '适合频繁识别',
          quotaTotal: 5000,
          retentionDays: 90,
          requireAd: false,
          priceCents: 9900,
          billingUnit: 'month',
        )),
        const SizedBox(height: 8),
        _buildPlanCard(PlanSetting(
          code: 'gold',
          name: '黄金',
          description: '更高额度',
          quotaTotal: 20000,
          retentionDays: 180,
          requireAd: false,
          priceCents: 19900,
          billingUnit: 'month',
        )),
        const SizedBox(height: 8),
        _buildPlanCard(PlanSetting(
          code: 'diamond',
          name: '钻石',
          description: '最高额度',
          quotaTotal: 100000,
          retentionDays: 365,
          requireAd: false,
          priceCents: 39900,
          billingUnit: 'month',
        )),
      ];
    }
    final widgets = <Widget>[];
    for (var i = 0; i < paidPlans.length; i++) {
      widgets.add(_buildPlanCard(paidPlans[i]));
      if (i != paidPlans.length - 1) {
        widgets.add(const SizedBox(height: 8));
      }
    }
    return widgets;
  }

  Widget _buildTile(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(value),
    );
  }

  Widget _buildPlanCard(PlanSetting plan) {
    final isCurrent = _ent?.plan == plan.code;
    return Card(
      child: ListTile(
        title: Text('${plan.name}档', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${plan.description} · ${plan.quotaTotal} 次额度 · 留存 ${plan.retentionDays} 天 · ${_formatPrice(plan)}',
        ),
        trailing: isCurrent
            ? const Chip(label: Text('当前'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _requestUpgrade(plan.code),
                    child: const Text('申请升级'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => _checkout(plan.code),
                    child: const Text('立即购买'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _requestUpgrade(String plan) async {
    final api = context.read<ApiService>();
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
    try {
      await api.paymentCheckout(plan: plan, method: 'wechat');
      _toast('支付功能未接入，已占位');
    } catch (_) {
      _toast('支付功能未接入，已占位');
    }
  }

  String _formatPrice(PlanSetting plan) {
    if (plan.priceCents <= 0) {
      return '免费';
    }
    final amount = (plan.priceCents / 100).toStringAsFixed(0);
    final unit = plan.billingUnit.isEmpty ? 'month' : plan.billingUnit;
    return '¥$amount/$unit';
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
