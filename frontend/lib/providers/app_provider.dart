import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

enum AppState { idle, loading, success, error }

class AppProvider extends ChangeNotifier {
  AppState _state = AppState.idle;
  String? _errorMessage;
  
  // 当前识别的数据
  File? _currentImage;
  UploadResponse? _uploadResponse;
  RecognizeResponse? _recognizeResult;
  
  // 历史记录
  List<RecognizeResponse> _history = [];
  
  // Getters
  AppState get state => _state;
  String? get errorMessage => _errorMessage;
  File? get currentImage => _currentImage;
  UploadResponse? get uploadResponse => _uploadResponse;
  RecognizeResponse? get recognizeResult => _recognizeResult;
  List<RecognizeResponse> get history => _history;
  
  void setLoading() {
    _state = AppState.loading;
    _errorMessage = null;
    notifyListeners();
  }
  
  void setSuccess() {
    _state = AppState.success;
    _errorMessage = null;
    notifyListeners();
  }
  
  void setError(String message) {
    _state = AppState.error;
    _errorMessage = message;
    notifyListeners();
  }
  
  void reset() {
    _state = AppState.idle;
    _errorMessage = null;
    _currentImage = null;
    _uploadResponse = null;
    _recognizeResult = null;
    notifyListeners();
  }
  
  void setCurrentImage(File image) {
    _currentImage = image;
    notifyListeners();
  }
  
  void setUploadResponse(UploadResponse response) {
    _uploadResponse = response;
    notifyListeners();
  }
  
  void setRecognizeResult(RecognizeResponse result) {
    _recognizeResult = result;
    notifyListeners();
  }
  
  void addToHistory(RecognizeResponse result) {
    _history.insert(0, result);
    notifyListeners();
  }
  
  void setHistory(List<RecognizeResponse> history) {
    _history = history;
    notifyListeners();
  }
}
