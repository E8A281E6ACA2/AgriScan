import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _tokenController = TextEditingController();
  final _searchController = TextEditingController();
  final _quotaController = TextEditingController();
  final _usedController = TextEditingController();
  final _creditsController = TextEditingController();

  bool _loading = false;
  List<AdminUser> _users = [];
  AdminUser? _selected;
  String _plan = 'free';
  String _status = 'active';

  @override
  void dispose() {
    _tokenController.dispose();
    _searchController.dispose();
    _quotaController.dispose();
    _usedController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _toast('请输入管理员 Token');
      return;
    }
    setState(() => _loading = true);
    try {
      final users = await api.adminListUsers(
        adminToken: token,
        q: _searchController.text.trim(),
      );
      setState(() => _users = users);
    } catch (e) {
      _toast('拉取用户失败: $e');
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

  Future<void> _purgeUser() async {
    final api = context.read<ApiService>();
    final token = _tokenController.text.trim();
    final user = _selected;
    if (token.isEmpty || user == null) return;
    setState(() => _loading = true);
    try {
      await api.adminPurgeUser(user.id, adminToken: token);
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
                labelText: '管理员 Token',
              ),
            ),
            const SizedBox(height: 8),
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
                              return ListTile(
                                title: Text(u.email),
                                subtitle: Text('${u.plan} | used ${u.quotaUsed}'),
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
                                    onPressed: _loading ? null : _purgeUser,
                                    child: const Text('按留存清理'),
                                  ),
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
}
