// lib/core/quick_ping.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dong_story/core/env.dart';

Future<void> quickPingHealth() async {
  try {
    final uri = Uri.parse('${Env.baseUrl}/health');
    final client = HttpClient();
    final req = await client.getUrl(uri);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    debugPrint('[HEALTH] ${res.statusCode}  $body');
  } catch (e) {
    debugPrint('[HEALTH] ERROR $e');
  }
}
