import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/auth_flow.dart';
import '../utils/location_helper.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    _pickFromGallery();
  }
  
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _processImage(image);
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
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
      final position = await getBestEffortPosition();
      final bytes = await image.readAsBytes();
      provider.setCurrentImageBytes(bytes);

      provider.setLoading();
      final allowed = await ensureRecognitionAllowed(context, api);
      if (!allowed) {
        provider.setError('识别已取消');
        return;
      }
      final startedAt = DateTime.now();
      final uploadRes = await api.uploadImage(
        bytes,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      provider.setUploadResponse(uploadRes);

      final result = await api.recognize(uploadRes.imageId, source: 'gallery');
      provider.setRecognizeResult(result);
      provider.setRecognizeMeta(
        source: '相册',
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
      provider.addToHistory(result);

      provider.setSuccess();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/result');
      }
    } catch (e) {
      final handled = await handleRecognitionError(context, api, e);
      if (!handled) {
        provider.setError(e.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(explainNetworkError(e))),
          );
        }
      } else {
        provider.setError('识别已取消');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相册选择'),
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
            : const Text('请选择图片...'),
      ),
    );
  }
}
