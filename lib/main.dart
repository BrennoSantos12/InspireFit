import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/training_plan_repository.dart';
import 'repositories/training_session_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Em desktop (Linux/Windows/macOS) o sqflite usa o backend FFI.
  // No Android/iOS o backend nativo é usado automaticamente.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => CatalogRepository()),
        Provider(create: (_) => TrainingPlanRepository()),
        Provider(create: (_) => TrainingSessionRepository()),
        Provider(create: (_) => ReportRepository()),
      ],
      child: const InspireFitApp(),
    ),
  );
}
