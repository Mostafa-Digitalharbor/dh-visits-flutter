import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Compact, easy-to-read network logger for the Odoo API.
///
/// Replaces Dio's default `LogInterceptor` (which dumps every request
/// option on its own line). Output format:
///
/// ```
/// ┌── API → POST /api/visits  #42
/// │ body: {...pretty json...}
/// └──
/// ┌── API ← 200 OK  /api/visits  #42  (340ms)
/// │ {...pretty json...}
/// └──
/// ```
///
/// Errors get a distinct `✖` marker so you can scan the log fast. The
/// `password` field is masked. Bodies are truncated at 4 KB.
class PrettyLogInterceptor extends Interceptor {
  static int _counter = 0;
  static const _maxBodyChars = 4000;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    final id = ++_counter;
    options.extra['_prettyLogId'] = id;
    options.extra['_prettyLogStart'] = DateTime.now();
    final method = options.method;
    final path = _shortenPath(options.uri);

    final lines = <String>[
      '┌── API → $method $path  #$id',
    ];
    final body = options.data;
    if (body != null) {
      final pretty = _prettify(body);
      if (pretty.isNotEmpty) lines.add('│ $pretty');
    }
    if (options.queryParameters.isNotEmpty) {
      lines.add('│ query: ${jsonEncode(options.queryParameters)}');
    }
    lines.add('└──');
    _emit(lines);

    handler.next(options);
  }

  @override
  void onResponse(
      Response response, ResponseInterceptorHandler handler) {
    final opts = response.requestOptions;
    final id = opts.extra['_prettyLogId'] ?? '?';
    final start = opts.extra['_prettyLogStart'] as DateTime?;
    final ms = start != null
        ? DateTime.now().difference(start).inMilliseconds
        : null;
    final method = opts.method;
    final path = _shortenPath(opts.uri);
    final status = response.statusCode ?? 0;
    final marker = _isFailureStatus(status, response.data) ? '✖' : '←';

    final lines = <String>[
      '┌── API $marker $status  $method $path  #$id'
          '${ms != null ? '  (${ms}ms)' : ''}',
    ];
    final pretty = _prettify(response.data);
    if (pretty.isNotEmpty) lines.add('│ $pretty');
    lines.add('└──');
    _emit(lines);

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final opts = err.requestOptions;
    final id = opts.extra['_prettyLogId'] ?? '?';
    final start = opts.extra['_prettyLogStart'] as DateTime?;
    final ms = start != null
        ? DateTime.now().difference(start).inMilliseconds
        : null;
    final method = opts.method;
    final path = _shortenPath(opts.uri);
    final status = err.response?.statusCode;

    final lines = <String>[
      '┌── API ✖ ${err.type.name}${status != null ? ' ($status)' : ''}'
          '  $method $path  #$id'
          '${ms != null ? '  (${ms}ms)' : ''}',
    ];
    if (err.message != null && err.message!.isNotEmpty) {
      lines.add('│ msg: ${err.message}');
    }
    if (err.response?.data != null) {
      final pretty = _prettify(err.response!.data);
      if (pretty.isNotEmpty) lines.add('│ body: $pretty');
    }
    lines.add('└──');
    _emit(lines);

    handler.next(err);
  }

  void _emit(List<String> lines) {
    if (!kDebugMode) return;
    for (final l in lines) {
      debugPrint(l);
    }
  }

  String _shortenPath(Uri uri) {
    // Strip the host so the path is the focus of the log line.
    final q = uri.query.isEmpty ? '' : '?${uri.query}';
    return '${uri.path}$q';
  }

  bool _isFailureStatus(int status, dynamic body) {
    if (status >= 400) return true;
    if (body is Map) {
      if (body['status'] == 'error') return true;
      if (body['error'] != null) return true;
    }
    return false;
  }

  String _prettify(dynamic data) {
    try {
      // Try to JSON-encode whatever we got. Dio gives us either a Map,
      // a List, or a raw String — handle each.
      Object? jsonable;
      if (data is String) {
        try {
          jsonable = jsonDecode(data);
        } catch (_) {
          return _truncate(data);
        }
      } else {
        jsonable = data;
      }

      final masked = _maskSensitive(jsonable);
      final encoder = const JsonEncoder.withIndent('  ');
      final pretty = encoder.convert(masked);
      // The pretty-printed body is multi-line; route each line through
      // debugPrint so Android's logcat doesn't drop long messages.
      return _truncate(pretty).replaceAll('\n', '\n│ ');
    } catch (_) {
      return _truncate(data.toString());
    }
  }

  Object? _maskSensitive(Object? value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        final key = k.toString();
        if (_isSensitiveKey(key)) {
          out[key] = '***';
        } else {
          out[key] = _maskSensitive(v);
        }
      });
      return out;
    }
    if (value is List) {
      return value.map(_maskSensitive).toList();
    }
    return value;
  }

  bool _isSensitiveKey(String key) {
    final lc = key.toLowerCase();
    return lc == 'password' ||
        lc == 'access_token' ||
        lc == 'session_id' ||
        lc.contains('secret');
  }

  String _truncate(String s) {
    if (s.length <= _maxBodyChars) return s;
    final cut = s.substring(0, _maxBodyChars);
    return '$cut\n… (truncated ${s.length - _maxBodyChars} chars)';
  }
}
