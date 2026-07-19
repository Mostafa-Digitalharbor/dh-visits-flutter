// Pins the `call_kw` envelope these helpers generate.
//
// They replace ~22 hand-built envelopes across 7 repositories which had drifted
// — `search_read` fields were passed positionally (`args[1]`) in some repos and
// as `kwargs['fields']` in others. Odoo accepts both, so nothing ever forced
// them to converge. Since consolidating changes the wire format for the
// positional callers, the exact shape is asserted here rather than assumed.
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/api/endpoints.dart';
import 'package:location_gps/core/api/odoo_rpc.dart';

/// Captures the envelope instead of sending it. Implements ApiClient via
/// noSuchMethod so no cookie jar / Dio stack is needed.
class _CapturingClient implements ApiClient {
  String? path;
  Map<String, dynamic>? params;
  dynamic response;

  _CapturingClient({this.response});

  @override
  Future<dynamic> jsonRpc(String path, {Map<String, dynamic>? params}) async {
    this.path = path;
    this.params = params;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

void main() {
  group('searchRead', () {
    test('puts fields in kwargs, not args[1]', () async {
      // The drift this consolidation removes.
      final client = _CapturingClient(response: const []);
      await (client as ApiClient).searchRead(
        'dh.visit',
        domain: [
          ['state', '=', 'draft'],
        ],
        fields: ['id', 'name'],
        limit: 10,
        order: 'id desc',
      );

      expect(client.path, Endpoints.callKw);
      expect(client.params!['model'], 'dh.visit');
      expect(client.params!['method'], 'search_read');
      expect(client.params!['args'], [
        [
          ['state', '=', 'draft'],
        ],
      ]);
      final kwargs = client.params!['kwargs'] as Map;
      expect(kwargs['fields'], ['id', 'name']);
      expect(kwargs['limit'], 10);
      expect(kwargs['order'], 'id desc');
    });

    test('omits absent optionals rather than sending nulls', () async {
      // Odoo treats an explicit null limit differently from an absent one.
      final client = _CapturingClient(response: const []);
      await (client as ApiClient).searchRead('res.partner');

      final kwargs = client.params!['kwargs'] as Map;
      expect(kwargs.containsKey('limit'), isFalse);
      expect(kwargs.containsKey('order'), isFalse);
      expect(kwargs.containsKey('fields'), isFalse);
    });

    test('normalises rows to string-keyed maps', () async {
      final client = _CapturingClient(response: [
        {'id': 1, 'name': 'Acme'},
      ]);
      final rows = await (client as ApiClient).searchRead('res.partner');

      expect(rows, isA<List<Map<String, dynamic>>>());
      expect(rows.single['name'], 'Acme');
    });

    test('degrades to empty when Odoo returns false', () async {
      // Odoo answers `false` rather than [] in plenty of empty cases; that
      // used to be re-handled at each of the ~22 call sites.
      final client = _CapturingClient(response: false);
      expect(await (client as ApiClient).searchRead('res.partner'), isEmpty);
    });
  });

  group('readRecords', () {
    test('sends ids and fields positionally', () async {
      final client = _CapturingClient(response: const []);
      await (client as ApiClient)
          .readRecords('dh.visit', [1, 2], ['id', 'state']);

      expect(client.params!['method'], 'read');
      expect(client.params!['args'], [
        [1, 2],
        ['id', 'state'],
      ]);
    });

    test('short-circuits on empty ids without a round-trip', () async {
      final client = _CapturingClient(response: const []);
      final rows = await (client as ApiClient).readRecords('dh.visit', [], []);

      expect(rows, isEmpty);
      expect(client.path, isNull, reason: 'should not have called the server');
    });
  });

  group('searchCount', () {
    test('returns the count', () async {
      final client = _CapturingClient(response: 7);
      expect(await (client as ApiClient).searchCount('dh.visit'), 7);
      expect(client.params!['method'], 'search_count');
    });

    test('returns 0 for a non-numeric answer', () async {
      final client = _CapturingClient(response: false);
      expect(await (client as ApiClient).searchCount('dh.visit'), 0);
    });
  });

  group('createRecord / writeRecord', () {
    test('create returns the new id', () async {
      final client = _CapturingClient(response: 42);
      final id = await (client as ApiClient)
          .createRecord('dh.visit', {'name': 'V-1'});

      expect(id, 42);
      expect(client.params!['method'], 'create');
      expect(client.params!['args'], [
        {'name': 'V-1'},
      ]);
    });

    test('write reports success only on a true answer', () async {
      final ok = _CapturingClient(response: true);
      expect(
        await (ok as ApiClient).writeRecord('dh.visit', [1], {'state': 'done'}),
        isTrue,
      );

      final bad = _CapturingClient(response: false);
      expect(
        await (bad as ApiClient).writeRecord('dh.visit', [1], {'state': 'x'}),
        isFalse,
      );
    });
  });
}
