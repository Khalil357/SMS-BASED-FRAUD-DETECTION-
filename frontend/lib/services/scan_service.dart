import 'dart:convert';

import 'auth_service.dart';

class ScanService {
  static String _apiErrorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final details = errors.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join(', ');
          return message == null || message.isEmpty
              ? details
              : '$message ($details)';
        }
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Preserve the fallback when the backend returns a non-JSON error.
    }
    return fallback;
  }

  static Future<Map<String, dynamic>> fetchScans({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await AuthService.get('/api/scans?page=$page&size=$size');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': body['data'],
        };
      }

      return {
        'success': false,
        'message': _apiErrorMessage(response.body, 'Failed to load scans'),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not reach the scan backend: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> queryMessage({
    required String messageBody,
    String? sender,
    String source = 'MANUAL_QUERY',
  }) async {
    try {
      final response = await AuthService.post('/api/scans', {
        'messageBody': messageBody,
        if (sender != null && sender.isNotEmpty) 'sender': sender,
        'source': source,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': body['message'] ?? 'Scan saved',
          'data': body['data'],
        };
      }

      return {
        'success': false,
        'message': _apiErrorMessage(response.body, 'Scan failed'),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not reach the scan backend: $e',
      };
    }
  }
}
