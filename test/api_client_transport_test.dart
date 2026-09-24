// What the user ends up seeing when something other than Odoo's JSON-RPC
// layer answers: a proxy page, a redirect, a Wi-Fi login page, a dropped
// connection. Each of these used to surface as the wrong message ("feature not
// available" for a file that was too large), as silence (a redirect read as an
// empty result), or as a forced logout (a firewall's 403).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/api/endpoints.dart';
import 'package:location_gps/core/network/connectivity_status.dart';

/// One scripted reply: a body with a status, or a thrown error.
class _Reply {
  final int status;
  final String body;
  final String contentType;
  final Map<String, List<String>> headers;
  final List<RedirectRecord> redirects;
  final Object? error;

  const _Reply(
    this.status,
    this.body, {
    this.contentType = 'text/html',
    this.headers = const {},
    this.redirects = const [],
  }) : error = null;

  _Reply.json(Object json)
      : status = 200,
        body = jsonEncode(json),
        contentType = Headers.jsonContentType,
        headers = const {},
        redirects = const [],
        error = null;

  const _Reply.error(this.error)
      : status = 0,
        body = '',
        contentType = '',
        headers = const {},
        redirects = const [];
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final _Reply Function(RequestOptions options) reply;
  final List<RequestOptions> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    final r = reply(options);
    if (r.error != null) throw r.error!;
    return ResponseBody.fromString(
      r.body,
      r.status,
      headers: {
        Headers.contentTypeHeader: [r.contentType],
        ...r.headers,
      },
      isRedirect: r.redirects.isNotEmpty,
    )..redirects = r.redirects;
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient api, _Adapter adapter, ConnectivityStatus connectivity}) _client(
  _Reply Function(RequestOptions options) reply,
) {
  final dir = Directory.systemTemp.createTempSync('cookies');
  final connectivity = ConnectivityStatus();
  final api = ApiClient(
    cookieJar: PersistCookieJar(storage: FileStorage('${dir.path}/')),
    connectivity: connectivity,
    baseUrl: 'https://odoo.test',
  );
  final adapter = _Adapter(reply);
  api.dio.httpClientAdapter = adapter;
  return (api: api, adapter: adapter, connectivity: connectivity);
}

Matcher _code(ApiErrorCode code) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

const _html = '<!DOCTYPE html><html><body>…</body></html>';

void main() {
  group('non-Odoo answers', () {
    test('413 from a proxy means the file is too large, whatever the body',
        () async {
      final c = _client((_) => const _Reply(413, _html));
      await expectLater(
        c.api.jsonRpc(Endpoints.visitUploadAttachment),
        _code(ApiErrorCode.payloadTooLarge),
      );
    });

    test('429 is a rate limit', () async {
      final c = _client((_) => const _Reply(429, _html));
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.rateLimited));
    });

    test('website HTML on a module route means the module is missing',
        () async {
      final c = _client((_) => const _Reply(404, _html));
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.notSupported));
    });

    test('HTML on a core route means the answer is not from Odoo', () async {
      final c = _client((_) => const _Reply(200, _html));
      await expectLater(c.api.jsonRpc(Endpoints.versionInfo),
          _code(ApiErrorCode.invalidResponse));
    });

    test('a refused POST means the server is not Odoo, whatever the body',
        () async {
      for (final body in [_html, '{"error": "method not allowed"}']) {
        final c = _client((_) => _Reply(405, body));
        await expectLater(c.api.jsonRpc(Endpoints.authenticate),
            _code(ApiErrorCode.invalidResponse));
      }
    });

    test('a web page with a status of no specific meaning is not Odoo',
        () async {
      for (final status in [400, 410, 415]) {
        final c = _client((_) => _Reply(status, _html));
        await expectLater(c.api.jsonRpc('/api/visit/my'),
            _code(ApiErrorCode.invalidResponse));
      }
    });

    test('the same status without a web page stays unexplained', () async {
      final c = _client(
        (_) => const _Reply(418, '{}', contentType: Headers.jsonContentType),
      );
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.unknown));
    });

    test('a 200 without a JSON object is not a result', () async {
      final c = _client((_) => const _Reply(200, 'OK', contentType: 'text/plain'));
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.invalidResponse));
    });
  });

  group('redirects', () {
    test('an unfollowed redirect to the sign-in page re-authenticates',
        () async {
      var n = 0;
      final c = _client((_) => ++n == 1
          ? const _Reply(302, '', headers: {
              HttpHeaders.locationHeader: ['/web/login?redirect=%2Fapi'],
            })
          : _Reply.json({'result': 'ok'}));
      var renewals = 0;
      c.api.reauthenticate = () async {
        renewals++;
        return true;
      };
      expect(await c.api.jsonRpc('/api/visit/my'), 'ok');
      expect(renewals, 1);
    });

    test('any other unfollowed redirect is a stale server address', () async {
      final c = _client((_) => const _Reply(301, _html, headers: {
            HttpHeaders.locationHeader: ['https://new.example/api/visit/my'],
          }));
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.invalidResponse));
    });

    test('a followed redirect to another host is a captive portal', () async {
      final c = _client((_) => _Reply(200, _html, redirects: [
            RedirectRecord(302, 'GET', Uri.parse('https://wifi.hotel/login')),
          ]));
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.invalidResponse));
    });
  });

  group('who gets signed out', () {
    test("a firewall's 403 does not log the user out", () async {
      final c = _client((_) => const _Reply(403, _html));
      var loggedOut = 0;
      c.api.onUnauthorized.listen((_) => loggedOut++);
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.invalidResponse));
      await Future<void>.delayed(Duration.zero);
      expect(loggedOut, 0);
    });

    test('a probe that is refused neither re-authenticates nor logs out',
        () async {
      final c = _client((_) => _Reply.json({
            'error': {
              'code': 100,
              'message': 'Odoo Session Expired',
              'data': {'name': ApiException.sessionExpiredName},
            },
          }));
      var renewals = 0;
      c.api.reauthenticate = () async {
        renewals++;
        return true;
      };
      var loggedOut = 0;
      c.api.onUnauthorized.listen((_) => loggedOut++);

      await expectLater(
        c.api.jsonRpc(Endpoints.versionInfo, reportUnauthorized: false),
        _code(ApiErrorCode.unauthorized),
      );
      await Future<void>.delayed(Duration.zero);
      expect(renewals, 0);
      expect(loggedOut, 0);
    });
  });

  group('connection failures', () {
    test('a connection reset mid-response is a network problem', () async {
      final c = _client(
          (_) => const _Reply.error(SocketException('Connection reset by peer')));
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.network));
      expect(c.connectivity.isOnline, isFalse);
    });

    test('a body cut short mid-JSON is an unreadable reply', () async {
      final c = _client((_) => const _Reply(200, '{"result": [1, 2',
          contentType: Headers.jsonContentType));
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.invalidResponse));
    });

    test('a slow reply is a timeout but not "offline"', () async {
      final c = _client((o) => _Reply.error(DioException.receiveTimeout(
            timeout: const Duration(seconds: 30),
            requestOptions: o,
          )));
      await expectLater(
          c.api.jsonRpc('/api/visit/my'), _code(ApiErrorCode.timeout));
      expect(c.connectivity.isOnline, isTrue);
    });

    test('uploads get the longer upload timeouts', () async {
      final c = _client((_) => _Reply.json({'result': {'attachment_id': 1}}));
      await c.api.jsonRpc(Endpoints.visitUploadAttachment);
      await c.api.jsonRpc('/api/visit/my');
      expect(c.adapter.sent.first.sendTimeout,
          greaterThan(c.adapter.sent.last.sendTimeout!));
      expect(c.adapter.sent.first.receiveTimeout,
          greaterThan(c.adapter.sent.last.receiveTimeout!));
    });
  });
}
