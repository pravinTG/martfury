import 'package:flutter/foundation.dart';

/// Supported environments
enum AppEnv {
  dev,
  prod,
}

/// Global build configuration
class BuildConfig {
  BuildConfig._();

  /// Current environment.
  ///
  /// - Default: `dev`
  /// - To override at build time:
  ///   - Android: `flutter run --dart-define=APP_ENV=prod`
  ///   - iOS:     `flutter run --dart-define=APP_ENV=prod`
  static final AppEnv env = () {
    const String envString =
        String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    switch (envString.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnv.prod;
      case 'dev':
      case 'development':
      default:
        return AppEnv.dev;
    }
  }();

  /// Base URL per environment
  static String get baseUrl {
    switch (env) {
      case AppEnv.prod:
        return 'https://goodiesworld.techgigs.in';
      case AppEnv.dev:
        // TODO: change to your dev / staging URL when available
        return kDebugMode
            ? 'https://goodiesworld.techgigs.in' // using prod until dev ready
            : 'https://goodiesworld.techgigs.in';
    }
  }

  /// WooCommerce / backend consumer key per env
  static String get consumerKey {
    switch (env) {
      case AppEnv.prod:
        // PROD Consumer Key
        return 'ck_788d67b8f28f92f5a1a1bc7a6e9adf5a62c7f4fd';
      case AppEnv.dev:
        // TODO: add your DEV consumer key here
        return '';
    }
  }

  /// WooCommerce / backend consumer secret per env
  static String get consumerSecret {
    switch (env) {
      case AppEnv.prod:
        // PROD Consumer Secret
        return 'cs_c1dd92d3ab6cf683db2d5726e09ca5b261e6b972';
      case AppEnv.dev:
        // TODO: add your DEV consumer secret here
        return '';
    }
  }
}


