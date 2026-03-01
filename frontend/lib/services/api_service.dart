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
  
  void setDeviceId(String deviceId) {
    _dio.options.headers['X-Device-ID'] = deviceId;
  }

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('X-Auth-Token');
      return;
    }
    _dio.options.headers['X-Auth-Token'] = token;
  }

  void setUserId(int userId) {
    _dio.options.headers['X-User-ID'] = userId.toString();
  }
  
  // 上传图片 (兼容 Web)
  Future<UploadResponse> uploadImage(dynamic file, {double? latitude, double? longitude}) async {
    // Web 平台：file 是 bytes 或 base64 字符串
    // 其他平台：file 是 File 对象
    if (file is List<int>) {
      // Web bytes
      final base64Data = base64Encode(file);
      final formData = FormData.fromMap({
        'image': base64Data,
        'type': 'base64',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      final response = await _dio.post('/upload', data: formData);
      return UploadResponse.fromJson(response.data);
    } else if (file is String) {
      // 如果是 base64 字符串，需要明确传入；路径请用 File
      final formData = FormData.fromMap({
        'image': file,
        'type': 'base64',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      final response = await _dio.post('/upload', data: formData);
      return UploadResponse.fromJson(response.data);
    } else {
      // 移动端 File
      final formData = FormData.fromMap({
        'image': MultipartFile.fromFileSync(file.path),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
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
  Future<HistoryResponse> getHistory({
    int limit = 20,
    int offset = 0,
    String? cropType,
    double? minConfidence,
    double? maxConfidence,
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
    String? startDate,
    String? endDate,
  }) async {
    final response = await _dio.get('/history', queryParameters: {
      'limit': limit,
      'offset': offset,
      if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
      if (minConfidence != null) 'min_conf': minConfidence,
      if (maxConfidence != null) 'max_conf': maxConfidence,
      if (minLat != null) 'min_lat': minLat,
      if (maxLat != null) 'max_lat': maxLat,
      if (minLng != null) 'min_lng': minLng,
      if (maxLng != null) 'max_lng': maxLng,
      if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
      if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
    });
    return HistoryResponse.fromJson(response.data);
  }

  Future<Uint8List> exportHistory({
    String format = 'csv',
    String? cropType,
    double? minConfidence,
    double? maxConfidence,
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
    String? startDate,
    String? endDate,
  }) async {
    final response = await _dio.get(
      '/history/export',
      queryParameters: {
        'format': format,
        if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
        if (minConfidence != null) 'min_conf': minConfidence,
        if (maxConfidence != null) 'max_conf': maxConfidence,
        if (minLat != null) 'min_lat': minLat,
        if (maxLat != null) 'max_lat': maxLat,
        if (minLng != null) 'min_lng': minLng,
        if (maxLng != null) 'max_lng': maxLng,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data);
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
    bool? feedbackOnly,
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
    if (feedbackOnly != null) {
      params['feedback_only'] = feedbackOnly ? '1' : '0';
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

  Future<void> sendOTP(String email) async {
    await _dio.post('/auth/send-otp', data: {
      'email': email,
    });
  }

  Future<AuthResponse> verifyOTP({
    required String email,
    required String code,
    String? deviceId,
  }) async {
    final response = await _dio.post('/auth/verify-otp', data: {
      'email': email,
      'code': code,
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
    setAuthToken(null);
  }

  Future<Entitlements> getEntitlements() async {
    final response = await _dio.get('/entitlements');
    return Entitlements.fromJson(response.data);
  }

  Future<Entitlements> rewardAd() async {
    final response = await _dio.post('/usage/reward');
    return Entitlements.fromJson(response.data);
  }

  Options _adminOptions(String? adminToken) {
    if (adminToken == null || adminToken.isEmpty) {
      return Options();
    }
    return Options(headers: {'X-Admin-Token': adminToken});
  }

  Future<List<AdminUser>> adminListUsers({
    int limit = 20,
    int offset = 0,
    String? q,
    String? plan,
    String? status,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/users',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (q != null && q.isNotEmpty) 'q': q,
        if (plan != null && plan.isNotEmpty) 'plan': plan,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => AdminUser.fromJson(e)).toList();
  }

  Future<AdminUser> adminUpdateUser(int id, AdminUserUpdate update, {String? adminToken}) async {
    final response = await _dio.put(
      '/admin/users/$id',
      data: update.toJson(),
      options: _adminOptions(adminToken),
    );
    return AdminUser.fromJson(response.data);
  }

  Future<void> adminPurgeUser(int id, {String? adminToken}) async {
    await _dio.post(
      '/admin/users/$id/purge',
      options: _adminOptions(adminToken),
    );
  }

  Future<List<EmailLog>> adminListEmailLogs({
    int limit = 50,
    int offset = 0,
    String? email,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/email-logs',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => EmailLog.fromJson(e)).toList();
  }

  Future<MembershipRequest> createMembershipRequest({
    required String plan,
    String? note,
  }) async {
    final response = await _dio.post('/membership/request', data: {
      'plan': plan,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return MembershipRequest.fromJson(response.data);
  }

  Future<void> paymentCheckout({required String plan, String method = 'wechat'}) async {
    await _dio.post('/payment/checkout', data: {
      'plan': plan,
      'method': method,
    });
  }

  Future<List<MembershipRequest>> adminListMembershipRequests({
    int limit = 50,
    int offset = 0,
    String? status,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/membership-requests',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => MembershipRequest.fromJson(e)).toList();
  }

  Future<AdminUser> adminApproveMembershipRequest(
    int id, {
    String? plan,
    int? quotaTotal,
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/membership-requests/$id/approve',
      data: {
        if (plan != null && plan.isNotEmpty) 'plan': plan,
        if (quotaTotal != null) 'quota_total': quotaTotal,
      },
      options: _adminOptions(adminToken),
    );
    return AdminUser.fromJson(response.data);
  }

  Future<void> adminRejectMembershipRequest(
    int id, {
    String? adminToken,
  }) async {
    await _dio.post(
      '/admin/membership-requests/$id/reject',
      options: _adminOptions(adminToken),
    );
  }

  Future<AdminUser> adminAddQuota(
    int id, {
    required int delta,
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/users/$id/quota',
      data: {'delta': delta},
      options: _adminOptions(adminToken),
    );
    return AdminUser.fromJson(response.data);
  }

  Future<Uint8List> adminExportUsers({String? adminToken}) async {
    final response = await _dio.get(
      '/admin/export/users',
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Uint8List> adminExportNotes({String? adminToken}) async {
    final response = await _dio.get(
      '/admin/export/notes',
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Uint8List> adminExportFeedback({String? adminToken}) async {
    final response = await _dio.get(
      '/admin/export/feedback',
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Uint8List> adminExportResults({
    String format = 'csv',
    String? startDate,
    String? endDate,
    String? provider,
    String? cropType,
    double? minConfidence,
    double? maxConfidence,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/export/results',
      queryParameters: {
        'format': format,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
        if (minConfidence != null) 'min_conf': minConfidence,
        if (maxConfidence != null) 'max_conf': maxConfidence,
      },
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Uint8List> adminExportFailures({
    String format = 'csv',
    String? startDate,
    String? endDate,
    String? stage,
    String? errorCode,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/export/failures',
      queryParameters: {
        'format': format,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
        if (stage != null && stage.isNotEmpty) 'stage': stage,
        if (errorCode != null && errorCode.isNotEmpty) 'error_code': errorCode,
      },
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<List<PlanSetting>> getPlans() async {
    final response = await _dio.get('/plans');
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => PlanSetting.fromJson(e)).toList();
  }

  Future<List<PlanSetting>> adminPlanSettings({String? adminToken}) async {
    final response = await _dio.get(
      '/admin/plan-settings',
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => PlanSetting.fromJson(e)).toList();
  }

  Future<PlanSetting> adminUpdatePlanSetting(
    String code,
    PlanSettingUpdate update, {
    String? adminToken,
  }) async {
    final response = await _dio.put(
      '/admin/plan-settings/$code',
      data: update.toJson(),
      options: _adminOptions(adminToken),
    );
    return PlanSetting.fromJson(response.data);
  }

  Future<List<AppSetting>> adminSettings({String? adminToken}) async {
    final response = await _dio.get(
      '/admin/settings',
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => AppSetting.fromJson(e)).toList();
  }

  Future<AppSetting> adminUpdateSetting(
    String key,
    AppSettingUpdate update, {
    String? adminToken,
  }) async {
    final response = await _dio.put(
      '/admin/settings/$key',
      data: update.toJson(),
      options: _adminOptions(adminToken),
    );
    return AppSetting.fromJson(response.data);
  }

  Future<Uint8List> adminExportEval({String format = 'csv', String? adminToken}) async {
    final response = await _dio.get(
      '/admin/export/eval',
      queryParameters: {'format': format},
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<AdminStats> adminStats({String? adminToken}) async {
    final response = await _dio.get(
      '/admin/stats',
      options: _adminOptions(adminToken),
    );
    return AdminStats.fromJson(response.data);
  }

  Future<AdminMetrics> adminMetrics({int days = 30, String? adminToken}) async {
    final response = await _dio.get(
      '/admin/metrics',
      queryParameters: {'days': days},
      options: _adminOptions(adminToken),
    );
    return AdminMetrics.fromJson(response.data);
  }

  Future<List<FailureTop>> adminFailureTop({
    int days = 7,
    int limit = 10,
    String? stage,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/failures/top',
      queryParameters: {
        'days': days,
        'limit': limit,
        if (stage != null && stage.isNotEmpty) 'stage': stage,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => FailureTop.fromJson(e)).toList();
  }

  Future<List<AdminAuditLog>> adminAuditLogs({
    int limit = 50,
    int offset = 0,
    String? action,
    String? targetType,
    String? startDate,
    String? endDate,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/audit-logs',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (action != null && action.isNotEmpty) 'action': action,
        if (targetType != null && targetType.isNotEmpty) 'target_type': targetType,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => AdminAuditLog.fromJson(e)).toList();
  }

  Future<Uint8List> adminExportAuditLogs({
    String format = 'csv',
    String? action,
    String? targetType,
    String? startDate,
    String? endDate,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/audit-logs/export',
      queryParameters: {
        'format': format,
        if (action != null && action.isNotEmpty) 'action': action,
        if (targetType != null && targetType.isNotEmpty) 'target_type': targetType,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<List<AdminLabelNote>> adminLabelQueue({
    int limit = 20,
    int offset = 0,
    String status = 'pending',
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/labels',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'status': status,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => AdminLabelNote.fromJson(e)).toList();
  }

  Future<void> adminLabelNote(
    int id, {
    required String category,
    required String cropType,
    required List<String> tags,
    String? note,
    String? adminToken,
  }) async {
    await _dio.post(
      '/admin/labels/$id',
      data: {
        'category': category,
        'crop_type': cropType,
        'tags': tags,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      options: _adminOptions(adminToken),
    );
  }

  Future<void> adminReviewLabel(
    int id, {
    required String status,
    String reviewer = 'admin',
    String? adminToken,
  }) async {
    await _dio.post(
      '/admin/labels/$id/review',
      data: {'status': status, 'reviewer': reviewer},
      options: _adminOptions(adminToken),
    );
  }

  Future<int> adminBatchApproveLabels({
    String status = 'labeled',
    String? category,
    String? cropType,
    String? reviewer,
    String? startDate,
    String? endDate,
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/labels/batch-approve',
      data: {
        'status': status,
        if (category != null && category.isNotEmpty) 'category': category,
        if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
        if (reviewer != null && reviewer.isNotEmpty) 'reviewer': reviewer,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: _adminOptions(adminToken),
    );
    return response.data['updated'] ?? 0;
  }

  Future<AdminNote> adminGetNoteByResult(int resultId, {String? adminToken}) async {
    final response = await _dio.get(
      '/admin/notes/by-result/$resultId',
      options: _adminOptions(adminToken),
    );
    return AdminNote.fromJson(response.data);
  }

  Future<EvalSummary> adminEvalSummary({int days = 30, String? adminToken}) async {
    final response = await _dio.get(
      '/admin/eval/summary',
      queryParameters: {'days': days},
      options: _adminOptions(adminToken),
    );
    return EvalSummary.fromJson(response.data);
  }

  Future<EvalRun> adminCreateEvalRun({int days = 30, String? adminToken}) async {
    final response = await _dio.post(
      '/admin/eval/runs',
      queryParameters: {'days': days},
      options: _adminOptions(adminToken),
    );
    return EvalRun.fromJson(response.data);
  }

  Future<List<EvalRun>> adminEvalRuns({int limit = 20, int offset = 0, String? adminToken}) async {
    final response = await _dio.get(
      '/admin/eval/runs',
      queryParameters: {'limit': limit, 'offset': offset},
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => EvalRun.fromJson(e)).toList();
  }

  Future<EvalSet> adminCreateEvalSet({
    required String name,
    String? description,
    int days = 30,
    int limit = 200,
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/eval-sets',
      data: {
        'name': name,
        if (description != null) 'description': description,
        'days': days,
        'limit': limit,
      },
      options: _adminOptions(adminToken),
    );
    return EvalSet.fromJson(response.data);
  }

  Future<List<EvalSet>> adminEvalSets({int limit = 20, int offset = 0, String? adminToken}) async {
    final response = await _dio.get(
      '/admin/eval-sets',
      queryParameters: {'limit': limit, 'offset': offset},
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => EvalSet.fromJson(e)).toList();
  }

  Future<EvalSetRun> adminRunEvalSet(
    int id, {
    int? baselineId,
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/eval-sets/$id/run',
      data: {
        if (baselineId != null) 'baseline_id': baselineId,
      },
      options: _adminOptions(adminToken),
    );
    return EvalSetRun.fromJson(response.data);
  }

  Future<List<EvalSetRun>> adminEvalSetRuns(
    int id, {
    int limit = 20,
    int offset = 0,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/eval-sets/$id/runs',
      queryParameters: {'limit': limit, 'offset': offset},
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => EvalSetRun.fromJson(e)).toList();
  }

  Future<Uint8List> adminExportEvalSet(
    int id, {
    String format = 'csv',
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/eval-sets/$id/export',
      queryParameters: {'format': format},
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<QCGenerateResult> adminGenerateQCSamples({
    int days = 30,
    int lowLimit = 0,
    int randomLimit = 0,
    int feedbackLimit = 0,
    double lowConfThreshold = 0.5,
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/qc/samples',
      queryParameters: {
        'days': days,
        'low_limit': lowLimit,
        'random_limit': randomLimit,
        'feedback_limit': feedbackLimit,
        'low_conf_threshold': lowConfThreshold,
      },
      options: _adminOptions(adminToken),
    );
    return QCGenerateResult.fromJson(response.data);
  }

  Future<List<QCSample>> adminListQCSamples({
    int limit = 20,
    int offset = 0,
    String? status,
    String? reason,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/qc/samples',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (status != null && status.isNotEmpty) 'status': status,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => QCSample.fromJson(e)).toList();
  }

  Future<void> adminReviewQCSample(
    int id, {
    required String status,
    String reviewer = 'admin',
    String? reviewNote,
    String? adminToken,
  }) async {
    await _dio.post(
      '/admin/qc/samples/$id/review',
      data: {'status': status, 'reviewer': reviewer, if (reviewNote != null) 'review_note': reviewNote},
      options: _adminOptions(adminToken),
    );
  }

  Future<int> adminBatchReviewQCSamples({
    required List<int> ids,
    required String status,
    String reviewer = 'admin',
    String? reviewNote,
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/qc/samples/batch-review',
      data: {
        'ids': ids,
        'status': status,
        'reviewer': reviewer,
        if (reviewNote != null) 'review_note': reviewNote,
      },
      options: _adminOptions(adminToken),
    );
    return response.data['updated'] ?? 0;
  }

  Future<Uint8List> adminExportQCSamples({
    String format = 'csv',
    String? status,
    String? reason,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/qc/samples/export',
      queryParameters: {
        'format': format,
        if (status != null && status.isNotEmpty) 'status': status,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<List<AdminResultItem>> adminLowConfidenceResults({
    int days = 30,
    int limit = 20,
    int offset = 0,
    double threshold = 0.5,
    String? provider,
    String? cropType,
    String? startDate,
    String? endDate,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/results/low-confidence',
      queryParameters: {
        'days': days,
        'limit': limit,
        'offset': offset,
        'threshold': threshold,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => AdminResultItem.fromJson(e)).toList();
  }

  Future<List<AdminResultItem>> adminFailedResults({
    int days = 30,
    int limit = 20,
    int offset = 0,
    String? provider,
    String? cropType,
    String? startDate,
    String? endDate,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/results/failed',
      queryParameters: {
        'days': days,
        'limit': limit,
        'offset': offset,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => AdminResultItem.fromJson(e)).toList();
  }

  Future<List<AdminResultItem>> adminSearchResults({
    int limit = 20,
    int offset = 0,
    String? provider,
    String? cropType,
    double? minConfidence,
    double? maxConfidence,
    String? startDate,
    String? endDate,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/results/search',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
        if (minConfidence != null) 'min_conf': minConfidence,
        if (maxConfidence != null) 'max_conf': maxConfidence,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: _adminOptions(adminToken),
    );
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => AdminResultItem.fromJson(e)).toList();
  }

  Future<Uint8List> adminExportLowConfidenceResults({
    String format = 'csv',
    int days = 30,
    double threshold = 0.5,
    String? provider,
    String? cropType,
    String? startDate,
    String? endDate,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/results/low-confidence/export',
      queryParameters: {
        'format': format,
        'days': days,
        'threshold': threshold,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Uint8List> adminExportFailedResults({
    String format = 'csv',
    int days = 30,
    String? provider,
    String? cropType,
    String? startDate,
    String? endDate,
    String? adminToken,
  }) async {
    final response = await _dio.get(
      '/admin/results/failed/export',
      queryParameters: {
        'format': format,
        'days': days,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (cropType != null && cropType.isNotEmpty) 'crop_type': cropType,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      options: Options(
        headers: adminToken == null || adminToken.isEmpty ? null : {'X-Admin-Token': adminToken},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<int> adminCreateQCSamplesFromResults({
    required List<int> ids,
    String? reason,
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/qc/samples/from-results',
      data: {
        'ids': ids,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
      options: _adminOptions(adminToken),
    );
    return response.data['created'] ?? 0;
  }

  Future<AdminLabelResult> adminLabelQCSample(
    int id, {
    String? category,
    String? cropType,
    List<String>? tags,
    String? note,
    bool approved = true,
    String reviewer = 'admin',
    String? adminToken,
  }) async {
    final response = await _dio.post(
      '/admin/qc/samples/$id/label',
      data: {
        if (category != null) 'category': category,
        if (cropType != null) 'crop_type': cropType,
        if (tags != null) 'tags': tags,
        if (note != null) 'note': note,
        'approved': approved,
        'reviewer': reviewer,
      },
      options: _adminOptions(adminToken),
    );
    return AdminLabelResult.fromJson(response.data);
  }

  Future<List<String>> getTags({String? category}) async {
    final response = await _dio.get('/tags', queryParameters: {
      if (category != null && category.isNotEmpty) 'category': category,
    });
    return List<String>.from(response.data['tags'] ?? []);
  }

  Future<List<ExportTemplate>> getExportTemplates({String type = 'notes'}) async {
    final response = await _dio.get('/export-templates', queryParameters: {
      'type': type,
    });
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => ExportTemplate.fromJson(e)).toList();
  }

  Future<ExportTemplate> createExportTemplate(ExportTemplateRequest req) async {
    final response = await _dio.post('/export-templates', data: req.toJson());
    return ExportTemplate.fromJson(response.data);
  }

  Future<void> deleteExportTemplate(int id) async {
    await _dio.delete('/export-templates/$id');
  }

  Future<List<Crop>> getCrops() async {
    final response = await _dio.get('/crops');
    final list = response.data['results'] as List? ?? [];
    return list.map((e) => Crop.fromJson(e)).toList();
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
  final double? confidenceLow;
  final double? confidenceHigh;
  final String description;
  final String? growthStage;
  final String? possibleIssue;
  final String provider;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String? riskLevel;
  final String? riskNote;
  final bool? feedbackCorrect;
  
  RecognizeResponse({
    this.rawText,
    required this.resultId,
    required this.imageId,
    required this.cropType,
    required this.confidence,
    this.confidenceLow,
    this.confidenceHigh,
    required this.description,
    this.growthStage,
    this.possibleIssue,
    required this.provider,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.riskLevel,
    this.riskNote,
    this.feedbackCorrect,
  });
  
  factory RecognizeResponse.fromJson(Map<String, dynamic> json) {
    return RecognizeResponse(
      rawText: json['raw_text'],
      resultId: json['result_id'] ?? json['id'] ?? 0,
      imageId: json['image_id'] ?? json['imageId'] ?? 0,
      cropType: json['crop_type'],
      confidence: (json['confidence'] as num).toDouble(),
      confidenceLow: json['confidence_low'] == null ? null : (json['confidence_low'] as num).toDouble(),
      confidenceHigh: json['confidence_high'] == null ? null : (json['confidence_high'] as num).toDouble(),
      description: json['description'] ?? '',
      growthStage: json['growth_stage'],
      possibleIssue: json['possible_issue'],
      provider: json['provider'],
      imageUrl: json['image_url'],
      latitude: json['latitude'] == null ? null : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] == null ? null : (json['longitude'] as num).toDouble(),
      riskLevel: json['risk_level'],
      riskNote: json['risk_note'],
      feedbackCorrect: json['feedback_correct'] == null ? null : json['feedback_correct'] as bool,
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
  final String? category;
  final List<String>? tags;
  
  FeedbackRequest({
    required this.resultId,
    this.correctedType,
    this.feedbackNote,
    required this.isCorrect,
    this.category,
    this.tags,
  });
  
  Map<String, dynamic> toJson() => {
    'result_id': resultId,
    'corrected_type': correctedType,
    'feedback_note': feedbackNote,
    'is_correct': isCorrect,
    'category': category,
    'tags': tags,
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
  final List<String> tags;
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
    required this.tags,
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
      tags: json['tags'] == null ? [] : List<String>.from(json['tags']),
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NoteRequest {
  final int imageId;
  final int? resultId;
  final String note;
  final String category;
  final List<String> tags;

  NoteRequest({
    required this.imageId,
    this.resultId,
    required this.note,
    required this.category,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
        'image_id': imageId,
        'result_id': resultId,
        'note': note,
        'category': category,
        'tags': tags,
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

class ExportTemplate {
  final int id;
  final String type;
  final String name;
  final String fields;

  ExportTemplate({
    required this.id,
    required this.type,
    required this.name,
    required this.fields,
  });

  factory ExportTemplate.fromJson(Map<String, dynamic> json) {
    return ExportTemplate(
      id: json['id'],
      type: json['type'] ?? 'notes',
      name: json['name'] ?? '',
      fields: json['fields'] ?? '',
    );
  }
}

class Crop {
  final int id;
  final String code;
  final String name;

  Crop({
    required this.id,
    required this.code,
    required this.name,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'],
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class ExportTemplateRequest {
  final String name;
  final String fields;
  final String type;

  ExportTemplateRequest({
    required this.name,
    required this.fields,
    this.type = 'notes',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'fields': fields,
        'type': type,
      };
}

class Entitlements {
  final int userId;
  final String plan;
  final bool requireLogin;
  final bool requireAd;
  final int adCredits;
  final int quotaTotal;
  final int quotaUsed;
  final int quotaRemaining;
  final int anonymousRemaining;
  final int retentionDays;

  Entitlements({
    required this.userId,
    required this.plan,
    required this.requireLogin,
    required this.requireAd,
    required this.adCredits,
    required this.quotaTotal,
    required this.quotaUsed,
    required this.quotaRemaining,
    required this.anonymousRemaining,
    required this.retentionDays,
  });

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    return Entitlements(
      userId: json['user_id'] ?? 0,
      plan: json['plan'] ?? 'free',
      requireLogin: json['require_login'] ?? false,
      requireAd: json['require_ad'] ?? false,
      adCredits: json['ad_credits'] ?? 0,
      quotaTotal: json['quota_total'] ?? 0,
      quotaUsed: json['quota_used'] ?? 0,
      quotaRemaining: json['quota_remaining'] ?? -1,
      anonymousRemaining: json['anonymous_remaining'] ?? 0,
      retentionDays: json['retention_days'] ?? 0,
    );
  }
}

class PlanSetting {
  final String code;
  final String name;
  final String description;
  final int quotaTotal;
  final int retentionDays;
  final bool requireAd;
  final int priceCents;
  final String billingUnit;

  PlanSetting({
    required this.code,
    required this.name,
    required this.description,
    required this.quotaTotal,
    required this.retentionDays,
    required this.requireAd,
    required this.priceCents,
    required this.billingUnit,
  });

  factory PlanSetting.fromJson(Map<String, dynamic> json) {
    return PlanSetting(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      quotaTotal: json['quota_total'] ?? 0,
      retentionDays: json['retention_days'] ?? 0,
      requireAd: json['require_ad'] ?? false,
      priceCents: json['price_cents'] ?? 0,
      billingUnit: json['billing_unit'] ?? '',
    );
  }
}

class PlanSettingUpdate {
  final String? name;
  final String? description;
  final int? quotaTotal;
  final int? retentionDays;
  final bool? requireAd;
  final int? priceCents;
  final String? billingUnit;

  PlanSettingUpdate({
    this.name,
    this.description,
    this.quotaTotal,
    this.retentionDays,
    this.requireAd,
    this.priceCents,
    this.billingUnit,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (quotaTotal != null) 'quota_total': quotaTotal,
        if (retentionDays != null) 'retention_days': retentionDays,
        if (requireAd != null) 'require_ad': requireAd,
        if (priceCents != null) 'price_cents': priceCents,
        if (billingUnit != null) 'billing_unit': billingUnit,
      };
}

class AppSetting {
  final String key;
  final String value;
  final String type;
  final String description;

  AppSetting({
    required this.key,
    required this.value,
    required this.type,
    required this.description,
  });

  factory AppSetting.fromJson(Map<String, dynamic> json) {
    return AppSetting(
      key: json['key'] ?? '',
      value: json['value']?.toString() ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class AppSettingUpdate {
  final dynamic value;

  AppSettingUpdate({required this.value});

  Map<String, dynamic> toJson() => {'value': value};
}

class AuthResponse {
  final String token;

  AuthResponse({required this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(token: json['token'] ?? '');
  }
}

class AdminUser {
  final int id;
  final String email;
  final String plan;
  final String status;
  final bool isAdmin;
  final int quotaTotal;
  final int quotaUsed;
  final int adCredits;

  AdminUser({
    required this.id,
    required this.email,
    required this.plan,
    required this.status,
    required this.isAdmin,
    required this.quotaTotal,
    required this.quotaUsed,
    required this.adCredits,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      plan: json['plan'] ?? 'free',
      status: json['status'] ?? 'active',
      isAdmin: json['is_admin'] ?? false,
      quotaTotal: json['quota_total'] ?? 0,
      quotaUsed: json['quota_used'] ?? 0,
      adCredits: json['ad_credits'] ?? 0,
    );
  }
}

class AdminUserUpdate {
  final String? plan;
  final String? status;
  final int? quotaTotal;
  final int? quotaUsed;
  final int? adCredits;

  AdminUserUpdate({
    this.plan,
    this.status,
    this.quotaTotal,
    this.quotaUsed,
    this.adCredits,
  });

  Map<String, dynamic> toJson() => {
        if (plan != null) 'plan': plan,
        if (status != null) 'status': status,
        if (quotaTotal != null) 'quota_total': quotaTotal,
        if (quotaUsed != null) 'quota_used': quotaUsed,
        if (adCredits != null) 'ad_credits': adCredits,
      };
}

class EmailLog {
  final int id;
  final String email;
  final String code;
  final String status;
  final String error;
  final String createdAt;

  EmailLog({
    required this.id,
    required this.email,
    required this.code,
    required this.status,
    required this.error,
    required this.createdAt,
  });

  factory EmailLog.fromJson(Map<String, dynamic> json) {
    return EmailLog(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      code: json['code'] ?? '',
      status: json['status'] ?? '',
      error: json['error'] ?? '',
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class MembershipRequest {
  final int id;
  final int userId;
  final String plan;
  final String status;
  final String note;
  final String createdAt;

  MembershipRequest({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  factory MembershipRequest.fromJson(Map<String, dynamic> json) {
    return MembershipRequest(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      plan: json['plan'] ?? '',
      status: json['status'] ?? '',
      note: json['note'] ?? '',
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class AdminStats {
  final int usersTotal;
  final int usersReal;
  final int usersGuest;
  final int usersActive7d;
  final int imagesTotal;
  final int resultsTotal;
  final int notesTotal;
  final int feedbackTotal;
  final int membershipPending;
  final int labelPending;
  final int labelApproved;
  final int labelToday;
  final int userQuotaTotal;
  final int userQuotaUsed;
  final int userAdCredits;
  final int deviceRecognize;
  final int deviceAdCredits;

  AdminStats({
    required this.usersTotal,
    required this.usersReal,
    required this.usersGuest,
    required this.usersActive7d,
    required this.imagesTotal,
    required this.resultsTotal,
    required this.notesTotal,
    required this.feedbackTotal,
    required this.membershipPending,
    required this.labelPending,
    required this.labelApproved,
    required this.labelToday,
    required this.userQuotaTotal,
    required this.userQuotaUsed,
    required this.userAdCredits,
    required this.deviceRecognize,
    required this.deviceAdCredits,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      usersTotal: json['users_total'] ?? 0,
      usersReal: json['users_real'] ?? 0,
      usersGuest: json['users_guest'] ?? 0,
      usersActive7d: json['users_active_7d'] ?? 0,
      imagesTotal: json['images_total'] ?? 0,
      resultsTotal: json['results_total'] ?? 0,
      notesTotal: json['notes_total'] ?? 0,
      feedbackTotal: json['feedback_total'] ?? 0,
      membershipPending: json['membership_pending'] ?? 0,
      labelPending: json['label_pending'] ?? 0,
      labelApproved: json['label_approved'] ?? 0,
      labelToday: json['label_today'] ?? 0,
      userQuotaTotal: json['user_quota_total'] ?? 0,
      userQuotaUsed: json['user_quota_used'] ?? 0,
      userAdCredits: json['user_ad_credits'] ?? 0,
      deviceRecognize: json['device_recognize'] ?? 0,
      deviceAdCredits: json['device_ad_credits'] ?? 0,
    );
  }
}

class AdminMetrics {
  final List<DayCount> resultsByDay;
  final List<NamedCount> usersByPlan;
  final List<NamedCount> usersByStatus;
  final List<NamedCount> resultsByProvider;
  final List<NamedCount> resultsByCrop;
  final int feedbackTotal;
  final int feedbackCorrect;
  final double feedbackAccuracy;
  final int lowConfidenceTotal;
  final double lowConfidenceRatio;
  final double lowConfidenceThreshold;

  AdminMetrics({
    required this.resultsByDay,
    required this.usersByPlan,
    required this.usersByStatus,
    required this.resultsByProvider,
    required this.resultsByCrop,
    required this.feedbackTotal,
    required this.feedbackCorrect,
    required this.feedbackAccuracy,
    required this.lowConfidenceTotal,
    required this.lowConfidenceRatio,
    required this.lowConfidenceThreshold,
  });

  factory AdminMetrics.fromJson(Map<String, dynamic> json) {
    List<dynamic> listOrEmpty(dynamic v) => v is List ? v : [];
    return AdminMetrics(
      resultsByDay: listOrEmpty(json['results_by_day']).map((e) => DayCount.fromJson(e)).toList(),
      usersByPlan: listOrEmpty(json['users_by_plan']).map((e) => NamedCount.fromJson(e)).toList(),
      usersByStatus: listOrEmpty(json['users_by_status']).map((e) => NamedCount.fromJson(e)).toList(),
      resultsByProvider: listOrEmpty(json['results_by_provider']).map((e) => NamedCount.fromJson(e)).toList(),
      resultsByCrop: listOrEmpty(json['results_by_crop']).map((e) => NamedCount.fromJson(e)).toList(),
      feedbackTotal: json['feedback_total'] ?? 0,
      feedbackCorrect: json['feedback_correct'] ?? 0,
      feedbackAccuracy: (json['feedback_accuracy'] ?? 0).toDouble(),
      lowConfidenceTotal: json['low_confidence_total'] ?? 0,
      lowConfidenceRatio: (json['low_confidence_ratio'] ?? 0).toDouble(),
      lowConfidenceThreshold: (json['low_confidence_threshold'] ?? 0).toDouble(),
    );
  }
}

class FailureTop {
  final String stage;
  final String errorCode;
  final String errorMessage;
  final int count;
  final int retryTotal;

  FailureTop({
    required this.stage,
    required this.errorCode,
    required this.errorMessage,
    required this.count,
    required this.retryTotal,
  });

  factory FailureTop.fromJson(Map<String, dynamic> json) {
    return FailureTop(
      stage: json['stage'] ?? '',
      errorCode: json['error_code'] ?? '',
      errorMessage: (json['error_message'] ?? '').toString(),
      count: json['count'] ?? 0,
      retryTotal: json['retry_total'] ?? 0,
    );
  }
}

class DayCount {
  final String day;
  final int count;

  DayCount({required this.day, required this.count});

  factory DayCount.fromJson(Map<String, dynamic> json) {
    return DayCount(
      day: json['day'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class NamedCount {
  final String name;
  final int count;

  NamedCount({required this.name, required this.count});

  factory NamedCount.fromJson(Map<String, dynamic> json) {
    return NamedCount(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class AdminAuditLog {
  final int id;
  final String action;
  final String targetType;
  final int targetId;
  final String detail;
  final String ip;
  final String createdAt;

  AdminAuditLog({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.detail,
    required this.ip,
    required this.createdAt,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: json['id'] ?? 0,
      action: json['action'] ?? '',
      targetType: json['target_type'] ?? '',
      targetId: json['target_id'] ?? 0,
      detail: json['detail'] ?? '',
      ip: json['ip'] ?? '',
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class AdminLabelNote {
  final int id;
  final int userId;
  final int imageId;
  final String category;
  final String cropType;
  final String labelStatus;
  final String labelCropType;
  final String labelCategory;
  final String labelTags;

  AdminLabelNote({
    required this.id,
    required this.userId,
    required this.imageId,
    required this.category,
    required this.cropType,
    required this.labelStatus,
    required this.labelCropType,
    required this.labelCategory,
    required this.labelTags,
  });

  factory AdminLabelNote.fromJson(Map<String, dynamic> json) {
    return AdminLabelNote(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      imageId: json['image_id'] ?? 0,
      category: json['category'] ?? '',
      cropType: json['crop_type'] ?? '',
      labelStatus: json['label_status'] ?? '',
      labelCropType: json['label_crop_type'] ?? '',
      labelCategory: json['label_category'] ?? '',
      labelTags: json['label_tags'] ?? '',
    );
  }
}

class AdminNote {
  final int id;
  final int userId;
  final int imageId;
  final int? resultId;
  final String imageUrl;
  final String note;
  final String category;
  final String cropType;
  final double confidence;
  final String description;
  final String? growthStage;
  final String? possibleIssue;
  final String provider;
  final List<String> tags;
  final String labelStatus;
  final String labelCategory;
  final String labelCropType;
  final List<String> labelTags;
  final String createdAt;

  AdminNote({
    required this.id,
    required this.userId,
    required this.imageId,
    required this.resultId,
    required this.imageUrl,
    required this.note,
    required this.category,
    required this.cropType,
    required this.confidence,
    required this.description,
    required this.growthStage,
    required this.possibleIssue,
    required this.provider,
    required this.tags,
    required this.labelStatus,
    required this.labelCategory,
    required this.labelCropType,
    required this.labelTags,
    required this.createdAt,
  });

  factory AdminNote.fromJson(Map<String, dynamic> json) {
    List<dynamic> listOrEmpty(dynamic v) => v is List ? v : [];
    return AdminNote(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      imageId: json['image_id'] ?? 0,
      resultId: json['result_id'],
      imageUrl: json['image_url'] ?? '',
      note: json['note'] ?? '',
      category: json['category'] ?? '',
      cropType: json['crop_type'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      growthStage: json['growth_stage'],
      possibleIssue: json['possible_issue'],
      provider: json['provider'] ?? '',
      tags: listOrEmpty(json['tags']).map((e) => e.toString()).toList(),
      labelStatus: json['label_status'] ?? '',
      labelCategory: json['label_category'] ?? '',
      labelCropType: json['label_crop_type'] ?? '',
      labelTags: listOrEmpty(json['label_tags']).map((e) => e.toString()).toList(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class EvalSummary {
  final int total;
  final int correct;
  final double accuracy;
  final List<EvalCropStat> byCrop;
  final List<EvalConfusion> confusions;

  EvalSummary({
    required this.total,
    required this.correct,
    required this.accuracy,
    required this.byCrop,
    required this.confusions,
  });

  factory EvalSummary.fromJson(Map<String, dynamic> json) {
    final cropList = json['by_crop'] as List? ?? [];
    final confusionList = json['confusions'] as List? ?? [];
    return EvalSummary(
      total: json['total'] ?? 0,
      correct: json['correct'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      byCrop: cropList.map((e) => EvalCropStat.fromJson(e)).toList(),
      confusions: confusionList.map((e) => EvalConfusion.fromJson(e)).toList(),
    );
  }
}

class EvalRun {
  final int id;
  final String createdAt;
  final int days;
  final int total;
  final int correct;
  final double accuracy;

  EvalRun({
    required this.id,
    required this.createdAt,
    required this.days,
    required this.total,
    required this.correct,
    required this.accuracy,
  });

  factory EvalRun.fromJson(Map<String, dynamic> json) {
    return EvalRun(
      id: json['id'] ?? 0,
      createdAt: (json['created_at'] ?? '').toString(),
      days: json['days'] ?? 0,
      total: json['total'] ?? 0,
      correct: json['correct'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
    );
  }
}

class EvalSet {
  final int id;
  final String createdAt;
  final String name;
  final String description;
  final String source;
  final int size;

  EvalSet({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.description,
    required this.source,
    required this.size,
  });

  factory EvalSet.fromJson(Map<String, dynamic> json) {
    return EvalSet(
      id: json['id'] ?? 0,
      createdAt: (json['created_at'] ?? '').toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      source: json['source'] ?? '',
      size: json['size'] ?? 0,
    );
  }
}

class EvalSetRun {
  final int id;
  final String createdAt;
  final int total;
  final int correct;
  final double accuracy;
  final double deltaAcc;

  EvalSetRun({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.correct,
    required this.accuracy,
    required this.deltaAcc,
  });

  factory EvalSetRun.fromJson(Map<String, dynamic> json) {
    return EvalSetRun(
      id: json['id'] ?? 0,
      createdAt: (json['created_at'] ?? '').toString(),
      total: json['total'] ?? 0,
      correct: json['correct'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      deltaAcc: (json['delta_acc'] ?? 0).toDouble(),
    );
  }
}

class QCGenerateResult {
  final int requested;
  final int created;

  QCGenerateResult({required this.requested, required this.created});

  factory QCGenerateResult.fromJson(Map<String, dynamic> json) {
    return QCGenerateResult(
      requested: json['requested'] ?? 0,
      created: json['created'] ?? 0,
    );
  }
}

class QCSample {
  final int id;
  final int resultId;
  final int imageId;
  final String imageUrl;
  final String cropType;
  final double confidence;
  final String provider;
  final String reason;
  final String status;
  final String reviewer;
  final String? reviewedAt;
  final String reviewNote;
  final String createdAt;

  QCSample({
    required this.id,
    required this.resultId,
    required this.imageId,
    required this.imageUrl,
    required this.cropType,
    required this.confidence,
    required this.provider,
    required this.reason,
    required this.status,
    required this.reviewer,
    required this.reviewedAt,
    required this.reviewNote,
    required this.createdAt,
  });

  factory QCSample.fromJson(Map<String, dynamic> json) {
    return QCSample(
      id: json['id'] ?? 0,
      resultId: json['result_id'] ?? 0,
      imageId: json['image_id'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      cropType: json['crop_type'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      provider: json['provider'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? '',
      reviewer: json['reviewer'] ?? '',
      reviewedAt: json['reviewed_at'],
      reviewNote: json['review_note'] ?? '',
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class AdminResultItem {
  final int resultId;
  final int imageId;
  final String imageUrl;
  final String cropType;
  final double confidence;
  final String provider;
  final String createdAt;

  AdminResultItem({
    required this.resultId,
    required this.imageId,
    required this.imageUrl,
    required this.cropType,
    required this.confidence,
    required this.provider,
    required this.createdAt,
  });

  factory AdminResultItem.fromJson(Map<String, dynamic> json) {
    return AdminResultItem(
      resultId: json['result_id'] ?? 0,
      imageId: json['image_id'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      cropType: json['crop_type'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      provider: json['provider'] ?? '',
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class AdminLabelResult {
  final int noteId;
  final String status;

  AdminLabelResult({required this.noteId, required this.status});

  factory AdminLabelResult.fromJson(Map<String, dynamic> json) {
    return AdminLabelResult(
      noteId: json['note_id'] ?? 0,
      status: json['status'] ?? '',
    );
  }
}

class EvalCropStat {
  final String cropType;
  final int total;
  final int correct;
  final double accuracy;

  EvalCropStat({
    required this.cropType,
    required this.total,
    required this.correct,
    required this.accuracy,
  });

  factory EvalCropStat.fromJson(Map<String, dynamic> json) {
    return EvalCropStat(
      cropType: json['crop_type'] ?? '',
      total: json['total'] ?? 0,
      correct: json['correct'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
    );
  }
}

class EvalConfusion {
  final String actual;
  final String predicted;
  final int count;

  EvalConfusion({
    required this.actual,
    required this.predicted,
    required this.count,
  });

  factory EvalConfusion.fromJson(Map<String, dynamic> json) {
    return EvalConfusion(
      actual: json['actual'] ?? '',
      predicted: json['predicted'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}
