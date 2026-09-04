import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'token_storage.dart';

class ScanService {
  static Future<Map<String, dynamic>> fetchScans({
    int page = 0,
    int size = 20,
  }) async {
    final token = await TokenStorage.read();
    if (token == null) {
      return {'success': false, 'message': 'Not logged in'};
    }

    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/scans?page=$page&size=$size'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': body['data'],
        };
      }

      final err = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': false,
        'message': err['message'] ?? 'Failed to load scans',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> queryMessage({
    required String messageBody,
    String? sender,
  }) async {
    final token = await TokenStorage.read();
    if (token == null) {
      return {'success': false, 'message': 'Not logged in'};
    }

    try {
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/api/scans'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messageBody': messageBody,
          if (sender != null && sender.isNotEmpty) 'sender': sender,
          'source': 'MANUAL_QUERY',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': body['message'] ?? 'Scan saved',
          'data': body['data'],
        };
      }

      final err = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': false,
        'message': err['message'] ?? 'Scan failed',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
