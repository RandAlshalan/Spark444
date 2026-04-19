import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class PeriodicBackgroundService {
  Timer? _timer;
  bool _isActive = false;
  bool get isActive => _isActive;
  Duration get interval;
  Future<void> performCheck();
  String get guardMessage;
  String get startMessage;
  String get stopMessage;

  void startMonitoring() {
    if (_isActive) {
      debugPrint(guardMessage);
      return;
    }
    _isActive = true;
    debugPrint(startMessage);
    performCheck();
    _timer = Timer.periodic(interval, (_) {
      performCheck();
    });
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    _isActive = false;
    debugPrint(stopMessage);
  }
}
