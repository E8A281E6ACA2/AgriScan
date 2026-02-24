import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    _takePhoto();
  }
  
  Future<void> _takePhoto() async {
    try {
      // 尝试拍照
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _processImage(image);
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      // 相机不可用，提示用户
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请使用相册选择图片或确认相机权限')),
        );
        Navigator.pop(context);
      }
    }
  }
  
  Future<void> _processImage(XFile image) async {
    final provider = context.read<AppProvider>();
    final api = context.read<ApiService>();

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      provider.setCurrentImageBytes(bytes);

      provider.setLoading();
      final uploadRes = await api.uploadImage(bytes);
      provider.setUploadResponse(uploadRes);

      final result = await api.recognize(uploadRes.imageId);
      provider.setRecognizeResult(result);
      provider.addToHistory(result);

      provider.setSuccess();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/result');
      }
    } catch (e) {
      provider.setError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照识别'),
      ),
      body: Center(
        child: _isUploading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在上传并识别...'),
                ],
              )
            : const Text('准备拍照...'),
      ),
    );
  }
}
