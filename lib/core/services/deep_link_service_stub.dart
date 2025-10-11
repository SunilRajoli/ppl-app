// lib/core/services/deep_link_service_stub.dart
// Stub implementation for web platform (deep links not supported on web)

import 'package:flutter/material.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  Future<void> initialize(BuildContext context) async {
    // No-op on web
    debugPrint('ℹ️  Deep links are not supported on web platform');
  }

  void dispose() {
    // No-op on web
  }
}