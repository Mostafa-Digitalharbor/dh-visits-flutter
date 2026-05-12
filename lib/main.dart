import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app/app.dart';
import 'core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the full IANA timezone database so we can render Odoo datetimes
  // in the user's `res.users.tz` regardless of the device's clock.
  tz_data.initializeTimeZones();
  await setupServiceLocator();
  runApp(const CustomerVisitsApp());
}
