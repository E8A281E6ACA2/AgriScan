import 'dart:convert';
import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api/v1';
  
  late final Dio _dio;
  
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
  
  // 设置用户 ID
  void setUserId(int userId) {
    _dio.options.headers['X-User-ID'] = userId.toString();
  }
  
  // 上传图片 (兼容 Web)
  Future<UploadResponse> uploadImage(dynamic file) async {
    // Web 平台：file 是 bytes 或 base64 字符串
    // 其他平台：file 是 File 对象
    if (file is List<int>) {
      // Web bytes
      final base64Data = base64Encode(file);
      final response = await _dio.post('/upload', data: {
        'image': base64Data,
        'type': 'base64',
      });
      return UploadResponse.fromJson(response.data);
    } else if (file is String) {
      // 已经是 base64
      final response = await _dio.post('/upload', data: {
        'image': file,
        'type': 'base64',
      });
      return UploadResponse.fromJson(response.data);
    } else {
      // 移动端 File
      final formData = FormData.fromMap({
        'image': MultipartFile.fromFileSync(file.path),
      });
      final response = await _dio.post('/upload', data: formData);
      return UploadResponse.fromJson(response.data);
    }
  }
  
  // 发起识别
  Future<RecognizeResponse> recognize(int imageId) async {
    final response = await _dio.post('/recognize', data: {
      'image_id': imageId,
    });
    return RecognizeResponse.fromJson(response.data);
  }
  
  // 获取识别结果
  Future<RecognizeResponse> getResult(int imageId) async {
    final response = await _dio.get('/result/$imageId');
    return RecognizeResponse.fromJson(response.data);
  }
  
  // 获取历史记录
  Future<HistoryResponse> getHistory({int limit = 20, int offset = 0}) async {
    final response = await _dio.get('/history', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    return HistoryResponse.fromJson(response.data);
  }
  
  // 提交反馈
  Future<void> submitFeedback(FeedbackRequest request) async {
    await _dio.post('/feedback', data: request.toJson());
  }
  
  // 获取支持的提供商
  Future<List<String>> getProviders() async {
    final response = await _dio.get('/providers');
    return List<String>.from(response.data['providers']);
  }
}

// ========== Models ==========

class UploadResponse {
  final int imageId;
  final String originalUrl;
  final String compressedUrl;
  
  UploadResponse({
    required this.imageId,
    required this.originalUrl,
    required this.compressedUrl,
  });
  
  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      imageId: json['image_id'],
      originalUrl: json['original_url'],
      compressedUrl: json['compressed_url'],
    );
  }
}

class RecognizeResponse {
  final int resultId;
  final int imageId;
  final String cropType;
  final double confidence;
  final String description;
  final String? growthStage;
  final String? possibleIssue;
  final String provider;
  
  RecognizeResponse({
    required this.resultId,
    required this.imageId,
    required this.cropType,
    required this.confidence,
    required this.description,
    this.growthStage,
    this.possibleIssue,
    required this.provider,
  });
  
  factory RecognizeResponse.fromJson(Map<String, dynamic> json) {
    return RecognizeResponse(
      resultId: json['result_id'],
      imageId: json['image_id'] ?? 0,
      cropType: json['crop_type'],
      confidence: (json['confidence'] as num).toDouble(),
      description: json['description'] ?? '',
      growthStage: json['growth_stage'],
      possibleIssue: json['possible_issue'],
      provider: json['provider'],
    );
  }
}

class HistoryResponse {
  final List<RecognizeResponse> results;
  final int limit;
  final int offset;
  
  HistoryResponse({
    required this.results,
    required this.limit,
    required this.offset,
  });
  
  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    return HistoryResponse(
      results: (json['results'] as List)
          .map((e) => RecognizeResponse.fromJson(e))
          .toList(),
      limit: json['limit'],
      offset: json['offset'],
    );
  }
}

class FeedbackRequest {
  final int resultId;
  final String? correctedType;
  final String? feedbackNote;
  final bool isCorrect;
  
  FeedbackRequest({
    required this.resultId,
    this.correctedType,
    this.feedbackNote,
    required this.isCorrect,
  });
  
  Map<String, dynamic> toJson() => {
    'result_id': resultId,
    'corrected_type': correctedType,
    'feedback_note': feedbackNote,
    'is_correct': isCorrect,
  };
}
