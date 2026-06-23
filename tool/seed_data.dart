// ─────────────────────────────────────────────────────────────────────────────
// Seed data — populates the REAL Odoo server with a rich, realistic dataset so
// the whole app can be tested end-to-end before handing it to the team.
//
//   flutter run -d windows -t tool/seed_data.dart
//
// It drives the app's OWN repositories (no mock / no local data), so everything
// it writes is exactly what the app reads back. It:
//   1. Authenticates as admin (manager).
//   2. Lists the internal users → identifies the field employees to assign to.
//   3. Seeds ~8 customers (res.partner) with real Cairo/Giza coordinates.
//   4. Seeds the visit types (calendar.event.type).
//   5. Clears any previously app-seeded visits so re-runs stay clean.
//   6. Creates a curated spread of visits covering EVERY state:
//        • scheduled today (submit, no check-in)
//        • active now (checked-in, no check-out)
//        • pending review (checked-in + out + report → under_review)
//        • overdue (scheduled in the past, never started)
//        • completed (done) spread across the last 14 days for the charts
//   7. Reads everything back through VisitsRepository.list and prints a report
//      grouped by state + by employee, then exits.
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

// The fence the app stamps into every visit's `description`. Used here only to
// find + clear visits this app created on previous seed runs.
const _metaMarker = '⟦visit⟧';

final _odooDt = DateFormat('yyyy-MM-dd HH:mm:ss');
void _log(String m) => stdout.writeln('[seed] $m');

// ── Customers (real Cairo / Giza businesses, with coordinates) ───────────────
const _customers = <Map<String, dynamic>>[
  {'name': 'شركة النيل للتجارة', 'lat': 30.0626, 'lng': 31.2497, 'street': 'كورنيش النيل، وسط البلد', 'phone': '+20 100 123 4567'},
  {'name': 'مجموعة الدلتا الصناعية', 'lat': 30.0566, 'lng': 31.3300, 'street': 'المنطقة الصناعية، مدينة نصر', 'phone': '+20 100 234 5678'},
  {'name': 'الشركة المصرية للأغذية', 'lat': 29.9870, 'lng': 31.2118, 'street': 'شارع الهرم، الجيزة', 'phone': '+20 100 345 6789'},
  {'name': 'مصنع الأهرام للبلاستيك', 'lat': 29.9627, 'lng': 31.2497, 'street': 'شارع فيصل، الجيزة', 'phone': '+20 100 456 7890'},
  {'name': 'شركة القاهرة للأدوية', 'lat': 30.0808, 'lng': 31.2853, 'street': 'شارع الثورة، مصر الجديدة', 'phone': '+20 100 567 8901'},
  {'name': 'مجموعة المعادي التجارية', 'lat': 29.9602, 'lng': 31.2569, 'street': 'شارع 9، المعادي', 'phone': '+20 100 678 9012'},
  {'name': 'شركة الزمالك للاستيراد', 'lat': 30.0613, 'lng': 31.2197, 'street': 'شارع 26 يوليو، الزمالك', 'phone': '+20 100 789 0123'},
  {'name': 'مؤسسة أكتوبر للتوزيع', 'lat': 29.9660, 'lng': 30.9480, 'street': 'المحور المركزي، 6 أكتوبر', 'phone': '+20 100 890 1234'},
];

const _typeNames = ['متابعة', 'ديمو', 'تحصيل', 'صيانة', 'تركيب'];

const _reports = <String>[
  'تمّت بنجاح — تم عرض المنتجات وتحصيل المستحقات المتأخرة.',
  'تمّت بنجاح — اجتماع مع مسؤول المشتريات وتأكيد طلبية الشهر القادم.',
  'تمّت بنجاح — صيانة دورية للأجهزة وتدريب الفريق على التشغيل.',
  'تمّت بنجاح — تركيب الوحدة الجديدة واختبار التشغيل مع العميل.',
  'تمّت بنجاح — متابعة طلب سابق وحل ملاحظات الجودة.',
  'تمّت — تأجيل جزء من الطلب لحين توفر المخزون.',
];

late VisitsRepository _visits;
late ApiClient _api;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _run();
    _log('✅ DONE — database seeded and verified.');
  } catch (e, st) {
    _log('❌ FAILED: $e');
    _log(st.toString());
  }
  await Future.delayed(const Duration(milliseconds: 300));
  exit(0);
}

Future<void> _run() async {
  final tmp = await Directory.systemTemp.createTemp('cv_seed');
  final jar = PersistCookieJar(storage: FileStorage('${tmp.path}/cookies/'));
  _api = ApiClient(cookieJar: jar, baseUrl: _baseUrl);
  _visits = VisitsRepository(api: _api, session: SessionStorage());
  final customersRepo = CustomersRepository(api: _api);
  final employeesRepo = EmployeesRepository(api: _api);

  // 1) Authenticate as admin ──────────────────────────────────────────────────
  _log('1) Authenticating as admin…');
  final auth = await _api.jsonRpc(Endpoints.authenticate,
      params: {'db': _db, 'login': _login, 'password': _password});
  final adminUid = (auth['uid'] as num).toInt();
  _log('   ok — uid=$adminUid name=${auth['name']}');

  // 2) Identify field employees (internal users, admin excluded) ───────────────
  _log('2) Reading internal users…');
  final emps = await employeesRepo.list(limit: 80);
  _log('   ${emps.length} internal user(s):');
  for (final e in emps) {
    _log('   • #${e.userId} ${e.name} <${e.login ?? ''}>');
  }
  // Primary tester = the "Mostafa" account; the rest are extra field reps so the
  // leaderboards / review queue have more than one person.
  final mostafa = emps.firstWhere(
    (e) => e.name.toLowerCase().contains('mostafa') ||
        (e.login ?? '').toLowerCase().contains('mostafa'),
    orElse: () => emps.firstWhere((e) => e.userId != adminUid, orElse: () => emps.first),
  );
  final others = emps
      .where((e) => e.userId != adminUid && e.userId != mostafa.userId)
      .take(2)
      .toList();
  _log('   → primary field rep: #${mostafa.userId} ${mostafa.name}');
  if (others.isNotEmpty) {
    _log('   → extra field reps: ${others.map((e) => '#${e.userId} ${e.name}').join(', ')}');
  }

  // 3) Seed customers ──────────────────────────────────────────────────────────
  _log('3) Seeding ${_customers.length} customers…');
  final custIds = <int>[];
  for (final c in _customers) {
    final id = await _ensurePartner(c);
    custIds.add(id);
    _log('   • ${c['name']} → partner #$id');
  }

  // 4) Seed visit types ─────────────────────────────────────────────────────────
  _log('4) Seeding visit types…');
  final typeIds = <String, int>{};
  for (final t in _typeNames) {
    final id = await _ensureType(t);
    typeIds[t] = id;
    _log('   • $t → categ #$id');
  }

  // 5) Clear previously app-seeded visits (keep re-runs clean) ──────────────────
  _log('5) Clearing previously app-created visits…');
  final cleared = await _clearAppVisits();
  _log('   removed $cleared old app visit(s).');

  // 6) Create the curated spread ─────────────────────────────────────────────────
  _log('6) Creating visits…');
  final now = DateTime.now();
  DateTime day(int daysAgo) => DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));

  int customerPick = 0;
  Map<String, dynamic> nextCustomer() {
    final c = _customers[customerPick % _customers.length];
    customerPick++;
    return c;
  }

  var created = 0;

  // 6a) TODAY — 2 scheduled (submit, no check-in) for Mostafa
  for (var i = 0; i < 2; i++) {
    final c = nextCustomer();
    final ci = custIds[_customers.indexOf(c)];
    await _visits.create(
      customerId: ci,
      salespersonUserId: mostafa.userId,
      visitDate: now,
      visitTypeId: typeIds[_typeNames[i % _typeNames.length]],
      visitTypeName: _typeNames[i % _typeNames.length],
      customerName: c['name'] as String,
      customerLat: c['lat'] as double,
      customerLng: c['lng'] as double,
      customerAddress: c['street'] as String,
      customerPhone: c['phone'] as String,
      state: VisitLifecycleState.submit,
    );
    created++;
  }
  _log('   • 2 scheduled-today visits (Mostafa)');

  // 6b) TODAY — 1 active now (checked-in ~40 min ago, no check-out)
  {
    final c = nextCustomer();
    final ci = custIds[_customers.indexOf(c)];
    final id = await _visits.create(
      customerId: ci,
      salespersonUserId: mostafa.userId,
      visitDate: now,
      visitTypeId: typeIds['متابعة'],
      visitTypeName: 'متابعة',
      customerName: c['name'] as String,
      customerLat: c['lat'] as double,
      customerLng: c['lng'] as double,
      customerAddress: c['street'] as String,
      customerPhone: c['phone'] as String,
      state: VisitLifecycleState.submit,
    );
    final inAt = now.toUtc().subtract(const Duration(minutes: 40));
    await _visits.update(id, {
      'state': 'submit',
      'check_in_date_time': _odooDt.format(inAt),
      'check_in_lat': (c['lat'] as double) + 0.00015,
      'check_in_lng': (c['lng'] as double) + 0.00015,
    });
    created++;
    _log('   • 1 active-now visit (Mostafa, checked-in)');
  }

  // 6c) TODAY — 2 pending review (one in-range, one OUT of range/flagged)
  for (var i = 0; i < 2; i++) {
    final c = nextCustomer();
    final outOfRange = i == 1;
    await _seedReview(
      empId: mostafa.userId,
      cust: c,
      custId: custIds[_customers.indexOf(c)],
      typeId: typeIds[_typeNames[i % _typeNames.length]]!,
      typeName: _typeNames[i % _typeNames.length],
      onDay: now,
      ciHour: 10,
      durMin: 50 + i * 15,
      outOfRange: outOfRange,
      report: _reports[i % _reports.length],
    );
    created++;
  }
  _log('   • 2 pending-review visits (Mostafa, 1 flagged out-of-range)');

  // 6d) 1 overdue (scheduled 3 days ago, never started)
  {
    final c = nextCustomer();
    final ci = custIds[_customers.indexOf(c)];
    await _visits.create(
      customerId: ci,
      salespersonUserId: mostafa.userId,
      visitDate: day(3),
      visitTypeId: typeIds['تحصيل'],
      visitTypeName: 'تحصيل',
      customerName: c['name'] as String,
      customerLat: c['lat'] as double,
      customerLng: c['lng'] as double,
      customerAddress: c['street'] as String,
      customerPhone: c['phone'] as String,
      state: VisitLifecycleState.submit,
    );
    created++;
    _log('   • 1 overdue visit (Mostafa, scheduled 3 days ago)');
  }

  // 6e) Completed (done) spread across the last 14 days — feeds the charts,
  //     analytics, leaderboards and the user's history.
  //     Mostafa gets the bulk; extra reps get a few so leaderboards vary.
  final doneDaysMostafa = [1, 2, 2, 4, 5, 7, 9, 11, 13];
  var dr = 0;
  for (final d in doneDaysMostafa) {
    final c = nextCustomer();
    await _seedDone(
      empId: mostafa.userId,
      cust: c,
      custId: custIds[_customers.indexOf(c)],
      typeId: typeIds[_typeNames[dr % _typeNames.length]]!,
      typeName: _typeNames[dr % _typeNames.length],
      onDay: day(d),
      ciHour: 9 + (dr % 5),
      durMin: 45 + (dr % 4) * 20,
      report: _reports[dr % _reports.length],
    );
    created++;
    dr++;
  }
  _log('   • ${doneDaysMostafa.length} completed visits (Mostafa, last 14 days)');

  for (var e = 0; e < others.length; e++) {
    final emp = others[e];
    final doneDays = [1, 3, 6, 10];
    for (var k = 0; k < doneDays.length; k++) {
      final c = nextCustomer();
      await _seedDone(
        empId: emp.userId,
        cust: c,
        custId: custIds[_customers.indexOf(c)],
        typeId: typeIds[_typeNames[k % _typeNames.length]]!,
        typeName: _typeNames[k % _typeNames.length],
        onDay: day(doneDays[k]),
        ciHour: 10 + (k % 4),
        durMin: 40 + (k % 3) * 25,
        report: _reports[k % _reports.length],
      );
      created++;
    }
    // One pending-review each so the review queue shows more than one rep.
    final c = nextCustomer();
    await _seedReview(
      empId: emp.userId,
      cust: c,
      custId: custIds[_customers.indexOf(c)],
      typeId: typeIds['ديمو']!,
      typeName: 'ديمو',
      onDay: now,
      ciHour: 11,
      durMin: 55,
      outOfRange: false,
      report: _reports[e % _reports.length],
    );
    created += doneDays.length + 1;
    _log('   • ${doneDays.length} completed + 1 review (${emp.name})');
  }

  _log('   created $created visit(s) total.');

  // 7) Read back through the app's own repository + report ──────────────────────
  _log('7) Reading everything back (as the manager sees it)…');
  final all = await _visits.list(includeDrafts: true);
  final byState = <String, int>{};
  final byEmp = <String, int>{};
  var overdue = 0, activeNow = 0;
  for (final v in all) {
    final s = v.lifecycleState.name;
    byState[s] = (byState[s] ?? 0) + 1;
    final n = v.employeeName ?? '#${v.employeeId}';
    byEmp[n] = (byEmp[n] ?? 0) + 1;
    if (v.isOverdue) overdue++;
    if (v.state == VisitStateType.checkedIn) activeNow++;
  }
  _log('   total visits readable: ${all.length}');
  _log('   by lifecycle: ${byState.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
  _log('   by employee:  ${byEmp.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
  _log('   dashboard signals: overdue=$overdue · activeNow=$activeNow · '
      'pendingReview=${byState['underReview'] ?? 0}');

  // Sanity: every dashboard / screen needs at least one of each.
  // NB: VisitLifecycleState.name is camelCase → 'underReview', not 'under_review'.
  _assert((byState['submit'] ?? 0) > 0, 'has scheduled/submit visits');
  _assert((byState['underReview'] ?? 0) > 0, 'has pending-review visits');
  _assert((byState['done'] ?? 0) > 0, 'has completed visits');
  _assert(activeNow > 0, 'has an active (checked-in) visit');
  _assert(overdue > 0, 'has an overdue visit');

  // Customers + types reachable through their own repos.
  final custList = await customersRepo.list(limit: 80);
  _log('8) CustomersRepository.list → ${custList.length} customer(s) with coords.');
  final typeList = await _visits.listVisitTypes();
  _log('   VisitsRepository.listVisitTypes → ${typeList.length} type(s).');
  _assert(custList.length >= _customers.length, 'customers visible to the app');
}

// ── Seeders ──────────────────────────────────────────────────────────────────

/// Creates a completed (done) visit on [onDay] with check-in/out + report.
Future<void> _seedDone({
  required int empId,
  required Map<String, dynamic> cust,
  required int custId,
  required int typeId,
  required String typeName,
  required DateTime onDay,
  required int ciHour,
  required int durMin,
  required String report,
}) async {
  final id = await _visits.create(
    customerId: custId,
    salespersonUserId: empId,
    visitDate: onDay,
    visitTypeId: typeId,
    visitTypeName: typeName,
    customerName: cust['name'] as String,
    customerLat: cust['lat'] as double,
    customerLng: cust['lng'] as double,
    customerAddress: cust['street'] as String,
    customerPhone: cust['phone'] as String,
    state: VisitLifecycleState.submit,
  );
  final inAt = DateTime(onDay.year, onDay.month, onDay.day, ciHour, 12).toUtc();
  final outAt = inAt.add(Duration(minutes: durMin));
  await _visits.update(id, {
    'state': 'submit',
    'check_in_date_time': _odooDt.format(inAt),
    'check_in_lat': (cust['lat'] as double) + 0.0002,
    'check_in_lng': (cust['lng'] as double) + 0.0002,
  });
  await _visits.update(id, {
    'state': 'done',
    'check_out_date_time': _odooDt.format(outAt),
    'check_out_lat': (cust['lat'] as double) + 0.0001,
    'check_out_lng': (cust['lng'] as double) + 0.0001,
    'description': report,
  });
}

/// Creates a pending-review visit (checked-in + out + report, under_review).
/// When [outOfRange] the check-in/out coords are ~2 km away so the manager's
/// review card shows the red "out of range" banner.
Future<void> _seedReview({
  required int empId,
  required Map<String, dynamic> cust,
  required int custId,
  required int typeId,
  required String typeName,
  required DateTime onDay,
  required int ciHour,
  required int durMin,
  required bool outOfRange,
  required String report,
}) async {
  final id = await _visits.create(
    customerId: custId,
    salespersonUserId: empId,
    visitDate: onDay,
    visitTypeId: typeId,
    visitTypeName: typeName,
    customerName: cust['name'] as String,
    customerLat: cust['lat'] as double,
    customerLng: cust['lng'] as double,
    customerAddress: cust['street'] as String,
    customerPhone: cust['phone'] as String,
    state: VisitLifecycleState.submit,
  );
  final offset = outOfRange ? 0.02 : 0.0002; // ~2 km vs ~20 m
  final inAt = DateTime(onDay.year, onDay.month, onDay.day, ciHour, 8).toUtc();
  final outAt = inAt.add(Duration(minutes: durMin));
  await _visits.update(id, {
    'state': 'submit',
    'check_in_date_time': _odooDt.format(inAt),
    'check_in_lat': (cust['lat'] as double) + offset,
    'check_in_lng': (cust['lng'] as double) + offset,
  });
  await _visits.update(id, {
    'state': 'under_review',
    'check_out_date_time': _odooDt.format(outAt),
    'check_out_lat': (cust['lat'] as double) + offset,
    'check_out_lng': (cust['lng'] as double) + offset,
    'description': report,
  });
}

// ── Odoo helpers ──────────────────────────────────────────────────────────────

/// Deletes every `calendar.event` this app created (carries the meta marker).
Future<int> _clearAppVisits() async {
  final found = await _api.jsonRpc(Endpoints.callKw, params: {
    'model': 'calendar.event',
    'method': 'search',
    'args': [
      [
        ['description', 'like', _metaMarker],
      ],
    ],
    'kwargs': {},
  });
  final ids = (found is List ? found : <dynamic>[])
      .map((e) => (e as num).toInt())
      .toList();
  if (ids.isEmpty) return 0;
  await _api.jsonRpc(Endpoints.callKw, params: {
    'model': 'calendar.event',
    'method': 'unlink',
    'args': [ids],
    'kwargs': {},
  });
  return ids.length;
}

/// Find a `res.partner` by exact name or create it; ensure coords are set.
Future<int> _ensurePartner(Map<String, dynamic> c) async {
  final found = await _api.jsonRpc(Endpoints.callKw, params: {
    'model': 'res.partner',
    'method': 'search_read',
    'args': [
      [
        ['name', '=', c['name']],
      ],
    ],
    'kwargs': {'fields': ['id'], 'limit': 1},
  });
  if (found is List && found.isNotEmpty) {
    final id = ((found.first as Map)['id'] as num).toInt();
    await _api.jsonRpc(Endpoints.callKw, params: {
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
  final id = await _api.jsonRpc(Endpoints.callKw, params: {
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

/// Find a `calendar.event.type` by name or create it.
Future<int> _ensureType(String name) async {
  final found = await _api.jsonRpc(Endpoints.callKw, params: {
    'model': 'calendar.event.type',
    'method': 'search_read',
    'args': [
      [
        ['name', '=', name],
      ],
    ],
    'kwargs': {'fields': ['id'], 'limit': 1},
  });
  if (found is List && found.isNotEmpty) {
    return ((found.first as Map)['id'] as num).toInt();
  }
  final id = await _api.jsonRpc(Endpoints.callKw, params: {
    'model': 'calendar.event.type',
    'method': 'create',
    'args': [
      {'name': name},
    ],
    'kwargs': {},
  });
  return (id as num).toInt();
}

void _assert(bool cond, String label) {
  if (!cond) throw 'ASSERT FAILED: $label';
  _log('   ✓ $label');
}
