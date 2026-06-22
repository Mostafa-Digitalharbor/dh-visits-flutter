// ─────────────────────────────────────────────────────────────────────────────
// Backend smoke test — drives the FULL visit lifecycle against the REAL Odoo
// server using the app's OWN repositories (no mock / no local data).
//
//   flutter run -d windows -t tool/backend_smoke.dart
//
// It authenticates as admin, seeds customers + visit types, creates visits for
// the field rep "Mostafa Badr", then walks one visit through the whole cycle
// (manager create → employee check-in → check-out/report → manager review→done)
// and reads everything back through the same code paths the app uses. Prints a
// step-by-step report, then exits.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/api/endpoints.dart';
import 'package:location_gps/core/storage/session_storage.dart';
import 'package:location_gps/features/customers/data/customers_repository.dart';
import 'package:location_gps/features/employees/data/employees_repository.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';

const _baseUrl = 'https://dh-visits.odoo.com';
const _db = 'shawkialaddin-dh-visits-live-33591828';
const _login = 'admin';
const _password = '123';

final _odooDt = DateFormat('yyyy-MM-dd HH:mm:ss');
void _log(String m) => stdout.writeln('[smoke] $m');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _run();
    _log('✅ DONE — full cycle passed.');
  } catch (e, st) {
    _log('❌ FAILED: $e');
    _log(st.toString());
  }
  await Future.delayed(const Duration(milliseconds: 300));
  exit(0);
}

Future<void> _run() async {
  final tmp = await Directory.systemTemp.createTemp('cv_smoke');
  final jar = PersistCookieJar(storage: FileStorage('${tmp.path}/cookies/'));
  final api = ApiClient(cookieJar: jar, baseUrl: _baseUrl);
  final visits = VisitsRepository(api: api, session: SessionStorage());
  final customers = CustomersRepository(api: api);
  final employees = EmployeesRepository(api: api);

  // 1) Authenticate as admin (manager) ────────────────────────────────────────
  _log('1) Authenticating as admin…');
  final auth = await api.jsonRpc(Endpoints.authenticate,
      params: {'db': _db, 'login': _login, 'password': _password});
  _log('   ok — uid=${auth['uid']} name=${auth['name']}');

  // 2) Find the field rep "Mostafa Badr" ──────────────────────────────────────
  _log('2) Looking up field rep "Mostafa Badr"…');
  final users = await api.jsonRpc(Endpoints.callKw, params: {
    'model': 'res.users',
    'method': 'search_read',
    'args': [
      [
        ['name', 'ilike', 'Mostafa'],
      ],
    ],
    'kwargs': {
      'fields': ['id', 'name', 'login'],
      'limit': 5,
    },
  });
  if (users is! List || users.isEmpty) {
    throw 'No user matching "Mostafa" found.';
  }
  final mostafa = (users).whereType<Map>().first;
  final mostafaUid = (mostafa['id'] as num).toInt();
  _log('   ok — uid=$mostafaUid name=${mostafa['name']} login=${mostafa['login']}');

  // 3) Seed customers (res.partner) idempotently ──────────────────────────────
  _log('3) Seeding customers…');
  final seedCustomers = <Map<String, dynamic>>[
    {
      'name': 'شركة النيل للتجارة',
      'lat': 30.0626,
      'lng': 31.2497,
      'street': 'كورنيش النيل، وسط البلد',
      'phone': '+20 100 123 4567',
    },
    {
      'name': 'مجموعة الدلتا الصناعية',
      'lat': 30.0566,
      'lng': 31.3300,
      'street': 'المنطقة الصناعية، مدينة نصر',
      'phone': '+20 100 234 5678',
    },
    {
      'name': 'الشركة المصرية للأغذية',
      'lat': 29.9870,
      'lng': 31.2118,
      'street': 'شارع الهرم، الجيزة',
      'phone': '+20 100 345 6789',
    },
  ];
  final customerIds = <int>[];
  for (final c in seedCustomers) {
    final id = await _ensurePartner(api, c);
    customerIds.add(id);
    _log('   • ${c['name']} → partner #$id');
  }

  // 4) Seed visit types (calendar.event.type) idempotently ────────────────────
  _log('4) Seeding visit types…');
  final typeNames = ['متابعة', 'ديمو', 'تحصيل', 'صيانة'];
  final typeIds = <String, int>{};
  for (final t in typeNames) {
    final id = await _ensureType(api, t);
    typeIds[t] = id;
    _log('   • $t → categ #$id');
  }

  // 5) Manager creates several visits for Mostafa (today) ──────────────────────
  _log('5) Manager creates visits for Mostafa…');
  final today = DateTime.now();
  final created = <int>[];
  final plan = [
    {'ci': 0, 'type': 'تحصيل'},
    {'ci': 1, 'type': 'ديمو'},
    {'ci': 2, 'type': 'متابعة'},
  ];
  for (final p in plan) {
    final ci = p['ci'] as int;
    final tName = p['type'] as String;
    final c = seedCustomers[ci];
    final id = await visits.create(
      customerId: customerIds[ci],
      salespersonUserId: mostafaUid,
      visitDate: today,
      visitTypeId: typeIds[tName],
      visitTypeName: tName,
      customerName: c['name'] as String,
      customerLat: c['lat'] as double,
      customerLng: c['lng'] as double,
      customerAddress: c['street'] as String,
      customerPhone: c['phone'] as String,
      state: VisitLifecycleState.submit,
    );
    created.add(id);
    _log('   • created visit #$id → ${c['name']} ($tName) assigned to Mostafa');
  }

  // 6) Walk ONE visit through the full lifecycle (as the field rep would) ──────
  final target = created.first;
  final tc = seedCustomers[0];
  _log('6) Lifecycle on visit #$target (${tc['name']})…');

  // 6a) Employee check-in (in range — coords next to the customer)
  final nowIn = DateTime.now().toUtc();
  await visits.update(target, {
    'state': 'submit',
    'check_in_date_time': _odooDt.format(nowIn),
    'check_in_lat': (tc['lat'] as double) + 0.0002,
    'check_in_lng': (tc['lng'] as double) + 0.0002,
  });
  _log('   6a ✓ checked-in');

  // 6b) Employee check-out + report notes → under_review
  final nowOut = DateTime.now().toUtc().add(const Duration(seconds: 2));
  await visits.update(target, {
    'state': 'under_review',
    'check_out_date_time': _odooDt.format(nowOut),
    'check_out_lat': (tc['lat'] as double) + 0.0001,
    'check_out_lng': (tc['lng'] as double) + 0.0001,
    'description': 'تمّت بنجاح — تم عرض المنتجات وتحصيل المستحقات.',
  });
  _log('   6b ✓ checked-out + report submitted (under_review)');

  // 6c) Manager reviews → approve (done)
  await visits.update(target, {'state': 'done'});
  _log('   6c ✓ manager approved (done)');

  // 7) Read everything back through the app's parser + verify ──────────────────
  _log('7) Reading Mostafa\'s visits back through VisitsRepository.list…');
  final mine = await visits.list(employeeId: mostafaUid, includeDrafts: true);
  _log('   got ${mine.length} visit(s) for Mostafa:');
  for (final v in mine) {
    final flags = <String>[
      'state=${v.lifecycleState.name}',
      'mobile=${v.state.name}',
      if (v.checkInTime != null) 'in=${v.checkInTime!.toIso8601String()}',
      if (v.checkOutTime != null) 'out=${v.checkOutTime!.toIso8601String()}',
      if (v.visitTypeName != null) 'type=${v.visitTypeName}',
    ];
    _log('   • #${v.id} ${v.customerName} — ${flags.join(' · ')}');
  }

  final done = mine.where((v) => v.id == target).toList();
  if (done.isEmpty) {
    throw 'Lifecycle visit #$target did not come back in the list.';
  }
  final dv = done.first;
  _assert(dv.lifecycleState == VisitLifecycleState.done, 'visit is "done"');
  _assert(dv.checkInTime != null, 'has check-in time');
  _assert(dv.checkOutTime != null, 'has check-out time');
  _assert(dv.customerName == tc['name'], 'customer name round-trips');
  _assert(dv.visitTypeName == 'تحصيل', 'visit type round-trips');

  // 8) Confirm the customers + types are queryable through their repos ─────────
  final custList = await customers.list();
  _log('8) CustomersRepository.list → ${custList.length} customer(s) with coords.');
  final typeList = await visits.listVisitTypes();
  _log('   VisitsRepository.listVisitTypes → ${typeList.length} type(s).');
  final empList = await employees.list();
  _log('   EmployeesRepository.list → ${empList.length} employee(s).');
}

void _assert(bool cond, String label) {
  if (!cond) throw 'ASSERT FAILED: $label';
  _log('   ✓ $label');
}

/// Find a `res.partner` by exact name or create it. Returns its id.
Future<int> _ensurePartner(ApiClient api, Map<String, dynamic> c) async {
  final found = await api.jsonRpc(Endpoints.callKw, params: {
    'model': 'res.partner',
    'method': 'search_read',
    'args': [
      [
        ['name', '=', c['name']],
      ],
    ],
    'kwargs': {
      'fields': ['id'],
      'limit': 1,
    },
  });
  if (found is List && found.isNotEmpty) {
    final id = ((found.first as Map)['id'] as num).toInt();
    // Make sure coordinates are set (so it shows on the Customers map list).
    await api.jsonRpc(Endpoints.callKw, params: {
      'model': 'res.partner',
      'method': 'write',
      'args': [
        [id],
        {
          'partner_latitude': c['lat'],
          'partner_longitude': c['lng'],
          'street': c['street'],
          'phone': c['phone'],
          'city': 'القاهرة',
        },
      ],
      'kwargs': {},
    });
    return id;
  }
  final id = await api.jsonRpc(Endpoints.callKw, params: {
    'model': 'res.partner',
    'method': 'create',
    'args': [
      {
        'name': c['name'],
        'company_type': 'company',
        'partner_latitude': c['lat'],
        'partner_longitude': c['lng'],
        'street': c['street'],
        'phone': c['phone'],
        'city': 'القاهرة',
      },
    ],
    'kwargs': {},
  });
  return (id as num).toInt();
}

/// Find a `calendar.event.type` by name or create it. Returns its id.
Future<int> _ensureType(ApiClient api, String name) async {
  final found = await api.jsonRpc(Endpoints.callKw, params: {
    'model': 'calendar.event.type',
    'method': 'search_read',
    'args': [
      [
        ['name', '=', name],
      ],
    ],
    'kwargs': {
      'fields': ['id'],
      'limit': 1,
    },
  });
  if (found is List && found.isNotEmpty) {
    return ((found.first as Map)['id'] as num).toInt();
  }
  final id = await api.jsonRpc(Endpoints.callKw, params: {
    'model': 'calendar.event.type',
    'method': 'create',
    'args': [
      {'name': name},
    ],
    'kwargs': {},
  });
  return (id as num).toInt();
}
