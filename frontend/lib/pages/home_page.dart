import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../utils/auth_flow.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Entitlements? _ent;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEntitlements();
  }

  Future<void> _loadEntitlements() async {
    final api = context.read<ApiService>();
    setState(() => _loading = true);
    try {
      final ent = await api.getEntitlements();
      if (mounted) setState(() => _ent = ent);
    } catch (_) {
      if (mounted) setState(() => _ent = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final api = context.read<ApiService>();
    final ok = await startLoginFlow(context, api);
    if (ok) {
      await _loadEntitlements();
    }
  }

  Future<void> _logout() async {
    final api = context.read<ApiService>();
    final prefs = await SharedPreferences.getInstance();
    await api.logout();
    await prefs.remove('auth_token');
    await _loadEntitlements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.eco,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'AgriScan',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '智能作物识别',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              _buildEntCard(),
              const Spacer(),
              _buildFeatureButton(
                context,
                icon: Icons.camera_alt,
                label: '拍照识别',
                color: Theme.of(context).colorScheme.primary,
                onTap: () => Navigator.pushNamed(context, '/camera'),
              ),
              const SizedBox(height: 16),
              _buildFeatureButton(
                context,
                icon: Icons.photo_library,
                label: '相册选择',
                color: Colors.orange,
                onTap: () => Navigator.pushNamed(context, '/gallery'),
              ),
              const SizedBox(height: 16),
              _buildFeatureButton(
                context,
                icon: Icons.history,
                label: '历史记录',
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, '/history'),
              ),
              const SizedBox(height: 16),
              _buildFeatureButton(
                context,
                icon: Icons.note_alt,
                label: '手记',
                color: Colors.teal,
                onTap: () => Navigator.pushNamed(context, '/notes'),
              ),
              const SizedBox(height: 16),
              _buildFeatureButton(
                context,
                icon: Icons.card_membership,
                label: '会员权益',
                color: Colors.indigo,
                onTap: () => Navigator.pushNamed(context, '/membership'),
              ),
              const SizedBox(height: 16),
              _buildFeatureButton(
                context,
                icon: Icons.admin_panel_settings,
                label: '管理后台',
                color: Colors.grey,
                onTap: () => Navigator.pushNamed(context, '/admin'),
              ),
              const Spacer(),
              Text(
                'V1.0.0',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntCard() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final ent = _ent;
    final isLoggedIn = ent != null && ent.userId > 0;
    final planLabel = ent == null
        ? ''
        : (ent.planName.isNotEmpty && ent.planName != ent.plan)
            ? '${ent.planName}(${ent.plan})'
            : (ent.planName.isNotEmpty ? ent.planName : ent.plan);
    final title = isLoggedIn ? '已登录 · $planLabel' : '游客模式';
    final detail = isLoggedIn
        ? '剩余额度 ${ent!.quotaRemaining}'
        : '匿名剩余 ${ent?.anonymousRemaining ?? 0} 次';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _loadEntitlements,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text(detail),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isLoggedIn)
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: const Text('邮箱登录'),
                  ),
                if (isLoggedIn)
                  OutlinedButton(
                    onPressed: _loading ? null : _logout,
                    child: const Text('退出登录'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
