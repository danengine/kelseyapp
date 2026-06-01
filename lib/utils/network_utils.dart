import 'dart:async';
import 'dart:io';

import '../services/auth_service.dart';

bool isOfflineError(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    return msg.contains('could not reach') || msg.contains('connection');
  }
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  return false;
}
