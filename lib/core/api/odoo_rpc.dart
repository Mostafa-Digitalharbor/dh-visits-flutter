// odoo_rpc.dart — typed helpers over Odoo's `/web/dataset/call_kw`.
//
// Every repository used to hand-build the same envelope:
//
//   api.jsonRpc(Endpoints.callKw, params: {
//     'model': ..., 'method': 'search_read',
//     'args': [domain], 'kwargs': {'fields': ..., 'limit': ...},
//   })
//
// …then re-do the same `result is List ? result : []` + `.whereType<Map>()`
// unpacking. Repeated ~22× across 7 repositories, it had already drifted:
// `search_read` fields were passed positionally as `args[1]` in some places
// and as `kwargs['fields']` in others. Odoo accepts both, which is precisely
// why nothing ever forced the two to converge.
//
// These helpers make one shape canonical (kwargs) and do the unpacking once.
import 'api_client.dart';
import 'endpoints.dart';

/// Rows from a `search_read` / `read`, normalised to string-keyed maps.
/// Odoo returns `false` (not `null`/`[]`) for plenty of empty cases, so
/// anything that isn't a list of maps degrades to an empty list rather than
/// throwing a cast error deep inside a repository.
List<Map<String, dynamic>> _rows(dynamic result) {
  if (result is! List) return const [];
  return result
      .whereType<Map>()
      .map((r) => Map<String, dynamic>.from(r))
      .toList();
}

extension OdooRpc on ApiClient {
  /// `search_read`: filter by [domain], return [fields].
  ///
  /// Fields go in `kwargs` — the canonical spelling. See the note above on the
  /// args-vs-kwargs drift this replaces.
  Future<List<Map<String, dynamic>>> searchRead(
    String model, {
    List<dynamic> domain = const [],
    List<String> fields = const [],
    int? limit,
    int? offset,
    String? order,
    Map<String, dynamic>? context,
  }) async {
    final result = await jsonRpc(
      Endpoints.callKw,
      params: {
        'model': model,
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          if (fields.isNotEmpty) 'fields': fields,
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
          if (order != null) 'order': order,
          if (context != null) 'context': context,
        },
      },
    );
    return _rows(result);
  }

  /// `read`: fetch [fields] for known [ids].
  Future<List<Map<String, dynamic>>> readRecords(
    String model,
    List<int> ids,
    List<String> fields,
  ) async {
    if (ids.isEmpty) return const [];
    final result = await jsonRpc(
      Endpoints.callKw,
      params: {
        'model': model,
        'method': 'read',
        'args': [ids, fields],
        'kwargs': const {},
      },
    );
    return _rows(result);
  }

  /// `search_count`: how many records match [domain].
  Future<int> searchCount(
    String model, {
    List<dynamic> domain = const [],
  }) async {
    final result = await jsonRpc(
      Endpoints.callKw,
      params: {
        'model': model,
        'method': 'search_count',
        'args': [domain],
        'kwargs': const {},
      },
    );
    return result is num ? result.toInt() : 0;
  }

  /// `create`: write a new record, returning its id.
  Future<int?> createRecord(
    String model,
    Map<String, dynamic> values,
  ) async {
    final result = await jsonRpc(
      Endpoints.callKw,
      params: {
        'model': model,
        'method': 'create',
        'args': [values],
        'kwargs': const {},
      },
    );
    return result is num ? result.toInt() : null;
  }

  /// `write`: update [ids] with [values].
  Future<bool> writeRecord(
    String model,
    List<int> ids,
    Map<String, dynamic> values,
  ) async {
    final result = await jsonRpc(
      Endpoints.callKw,
      params: {
        'model': model,
        'method': 'write',
        'args': [ids, values],
        'kwargs': const {},
      },
    );
    return result == true;
  }

  /// Any other model method, for the cases these helpers don't cover.
  Future<dynamic> callMethod(
    String model,
    String method, {
    List<dynamic> args = const [],
    Map<String, dynamic> kwargs = const {},
  }) =>
      jsonRpc(
        Endpoints.callKw,
        params: {
          'model': model,
          'method': method,
          'args': args,
          'kwargs': kwargs,
        },
      );
}
