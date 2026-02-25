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
}
