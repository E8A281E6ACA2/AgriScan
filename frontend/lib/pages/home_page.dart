import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              // Logo 和标题
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
              const Spacer(),
              // 功能按钮
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
                icon: Icons.admin_panel_settings,
                label: '管理后台',
                color: Colors.grey,
                onTap: () => Navigator.pushNamed(context, '/admin'),
              ),
              const Spacer(),
              // 底部信息
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
