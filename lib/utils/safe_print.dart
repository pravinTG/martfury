import 'package:flutter/foundation.dart';

/// Safe print utility that only prints in debug mode
void safePrint(Object? object) {
  if (kDebugMode) {
    print(object);
  }
}


