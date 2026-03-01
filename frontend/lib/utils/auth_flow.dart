import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../services/api_service.dart';

Future<bool> ensureRecognitionAllowed(BuildContext context, ApiService api) async {
  Entitlements ent;
  try {
    ent = await api.getEntitlements();
  } catch (e) {
    _showToast(context, '获取权限失败: $e');
    return false;
  }

  if (ent.requireLogin) {
    final ok = await _loginFlow(context, api);
    if (!ok) return false;
    ent = await api.getEntitlements();
  }

  if (ent.requireAd) {
    final ok = await _adFlow(context, api);
    if (!ok) return false;
  }

  if (ent.quotaRemaining == 0) {
    final ok = await _quotaFlow(context);
    if (ok && context.mounted) {
      Navigator.pushNamed(context, '/membership');
    }
    return false;
  }

  return true;
}

Future<bool> handleRecognitionError(BuildContext context, ApiService api, Object error) async {
  final code = _extractEntitlementError(error);
  if (code == null) return false;
  switch (code) {
    case 'login_required':
      await _loginFlow(context, api);
      return true;
    case 'ad_required':
      await _adFlow(context, api);
      return true;
    case 'quota_exceeded':
      final ok = await _quotaFlow(context);
      if (ok && context.mounted) {
        Navigator.pushNamed(context, '/membership');
      }
      return true;
    default:
      return false;
  }
}

Future<bool> startLoginFlow(BuildContext context, ApiService api) async {
  return _loginFlow(context, api);
}

Future<bool> _loginFlow(BuildContext context, ApiService api) async {
  final email = await _promptText(context, title: '邮箱登录', hint: '请输入邮箱');
  if (email == null || email.isEmpty) return false;

  try {
    await api.sendOTP(email);
  } catch (e) {
    final msg = e.toString().contains('too_many_requests')
        ? '发送过于频繁，请稍后再试'
        : '发送验证码失败: $e';
    _showToast(context, msg);
    return false;
  }

  final code = await _promptText(context, title: '输入验证码', hint: '邮箱验证码');
  if (code == null || code.isEmpty) return false;

  try {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    final auth = await api.verifyOTP(email: email, code: code, deviceId: deviceId);
    if (auth.token.isNotEmpty) {
      api.setAuthToken(auth.token);
      await prefs.setString('auth_token', auth.token);
      _showToast(context, '登录成功');
      return true;
    }
    _showToast(context, '登录失败');
    return false;
  } catch (e) {
    _showToast(context, '验证码错误或已过期');
    return false;
  }
}

Future<bool> _adFlow(BuildContext context, ApiService api) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('观看广告'),
        content: const Text('每次识别需观看一条广告，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('观看广告'),
          ),
        ],
      );
    },
  );
  if (ok != true) return false;
  try {
    await api.rewardAd();
    return true;
  } catch (e) {
    _showToast(context, '广告奖励失败: $e');
    return false;
  }
}

String? _extractEntitlementError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    if (data is String) {
      if (data.contains('login_required')) return 'login_required';
      if (data.contains('ad_required')) return 'ad_required';
      if (data.contains('quota_exceeded')) return 'quota_exceeded';
    }
    if (status == 401) return 'login_required';
    if (status == 403) return 'ad_required';
    if (status == 402) return 'quota_exceeded';
  }
  final raw = error.toString();
  if (raw.contains('login_required')) return 'login_required';
  if (raw.contains('ad_required')) return 'ad_required';
  if (raw.contains('quota_exceeded')) return 'quota_exceeded';
  return null;
}

Future<bool> _quotaFlow(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('额度已用完'),
        content: const Text('当前额度不足，是否前往会员中心开通？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('去开通'),
          ),
        ],
      );
    },
  );
  return ok == true;
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确认'),
          ),
        ],
      );
    },
  );
  return result;
}

void _showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
