import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );
  
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
      final formData = FormData.fromMap({
        'image': base64Data,
        'type': 'base64',
      });
      final response = await _dio.post('/upload', data: formData);
      return UploadResponse.fromJson(response.data);
    } else if (file is String) {
      // 如果是 base64 字符串，需要明确传入；路径请用 File
      final formData = FormData.fromMap({
        'image': file,
        'type': 'base64',
      });
      final response = await _dio.post('/upload', data: formData);
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
  
  // 获取识别结果（按 result_id）
  Future<RecognizeResponse> getResult(int resultId) async {
    final response = await _dio.get('/result/$resultId');
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

  // 创建手记
  Future<Note> createNote(NoteRequest request) async {
    final response = await _dio.post('/notes', data: request.toJson());
    return Note.fromJson(response.data);
  }

  // 获取手记列表
  Future<NotesResponse> getNotes({
    int limit = 20,
    int offset = 0,
    String? category,
    String? cropType,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }
    if (cropType != null && cropType.isNotEmpty) {
      params['crop_type'] = cropType;
    }
    if (startDate != null && startDate.isNotEmpty) {
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['end_date'] = endDate;
    }

    final response = await _dio.get('/notes', queryParameters: params);
    return NotesResponse.fromJson(response.data);
  }

  Future<Uint8List> exportNotes(Map<String, dynamic> params) async {
    final response = await _dio.get(
      '/notes/export',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data);
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
  final String? rawText;
  final int resultId;
  final int imageId;
  final String cropType;
  final double confidence;
  final String description;
  final String? growthStage;
  final String? possibleIssue;
  final String provider;
  final String? imageUrl;
  
  RecognizeResponse({
    this.rawText,
    required this.resultId,
    required this.imageId,
    required this.cropType,
    required this.confidence,
    required this.description,
    this.growthStage,
    this.possibleIssue,
    required this.provider,
    this.imageUrl,
  });
  
  factory RecognizeResponse.fromJson(Map<String, dynamic> json) {
    return RecognizeResponse(
      rawText: json['raw_text'],
      resultId: json['result_id'] ?? json['id'] ?? 0,
      imageId: json['image_id'] ?? json['imageId'] ?? 0,
      cropType: json['crop_type'],
      confidence: (json['confidence'] as num).toDouble(),
      description: json['description'] ?? '',
      growthStage: json['growth_stage'],
      possibleIssue: json['possible_issue'],
      provider: json['provider'],
      imageUrl: json['image_url'],
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

class Note {
  final int id;
  final int imageId;
  final int? resultId;
  final String imageUrl;
  final String note;
  final String category;
  final String? cropType;
  final double? confidence;
  final String? description;
  final String? growthStage;
  final String? possibleIssue;
  final String? provider;
  final String createdAt;

  Note({
    required this.id,
    required this.imageId,
    this.resultId,
    required this.imageUrl,
    required this.note,
    required this.category,
    this.cropType,
    this.confidence,
    this.description,
    this.growthStage,
    this.possibleIssue,
    this.provider,
    required this.createdAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      imageId: json['image_id'],
      resultId: json['result_id'],
      imageUrl: json['image_url'] ?? '',
      note: json['note'] ?? '',
      category: json['category'] ?? 'crop',
      cropType: json['crop_type'],
      confidence: json['confidence'] == null
          ? null
          : (json['confidence'] as num).toDouble(),
      description: json['description'],
      growthStage: json['growth_stage'],
      possibleIssue: json['possible_issue'],
      provider: json['provider'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NoteRequest {
  final int imageId;
  final int? resultId;
  final String note;
  final String category;

  NoteRequest({
    required this.imageId,
    this.resultId,
    required this.note,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'image_id': imageId,
        'result_id': resultId,
        'note': note,
        'category': category,
      };
}

class NotesResponse {
  final List<Note> results;
  final int limit;
  final int offset;

  NotesResponse({
    required this.results,
    required this.limit,
    required this.offset,
  });

  factory NotesResponse.fromJson(Map<String, dynamic> json) {
    return NotesResponse(
      results: (json['results'] as List)
          .map((e) => Note.fromJson(e))
          .toList(),
      limit: json['limit'],
      offset: json['offset'],
    );
  }
}
