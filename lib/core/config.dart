import 'package:flutter/foundation.dart';

class AppConfig {
  static const _backendUrlOverride = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  /// API base URL.
  /// - `--dart-define=BACKEND_URL=...` があればそれを使う
  /// - Web で未指定なら同一オリジン（Cloud Run で API+静的配信する構成）
  /// - それ以外はローカル Backend 既定値
  static String get backendUrl {
    if (_backendUrlOverride.isNotEmpty) {
      return _backendUrlOverride;
    }
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'http://localhost:8080';
  }
}
