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
  final TextEditingController _noteController = TextEditingController();

  Future<void> _load() async {
    final api = context.read<ApiService>();
    setState(() => _loading = true);
    try {
      final ent = await api.getEntitlements();
      setState(() => _ent = ent);
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
                    _buildPlanCard('白银', 'silver', '适合频繁识别', '5000+ 次额度'),
                    const SizedBox(height: 8),
                    _buildPlanCard('黄金', 'gold', '更高额度', '20000+ 次额度'),
                    const SizedBox(height: 8),
                    _buildPlanCard('钻石', 'diamond', '最高额度', '100000+ 次额度'),
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

  Widget _buildTile(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(value),
    );
  }

  Widget _buildPlanCard(String title, String plan, String desc, String quotaHint) {
    final isCurrent = _ent?.plan == plan;
    return Card(
      child: ListTile(
        title: Text('$title档', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$desc · $quotaHint'),
        trailing: isCurrent
            ? const Chip(label: Text('当前'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _requestUpgrade(plan),
                    child: const Text('申请升级'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => _checkout(plan),
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
