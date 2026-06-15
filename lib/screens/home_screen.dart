import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/models.dart';
import '../repositories/training_plan_repository.dart';
import '../repositories/training_session_repository.dart';
import '../theme/app_theme.dart';
import 'edit_session_screen.dart';
import 'fichas_screen.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  static const route = '/';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TrainingPlanRepository get _plans => context.read<TrainingPlanRepository>();
  TrainingSessionRepository get _sessions =>
      context.read<TrainingSessionRepository>();

  bool _loading = true;
  TrainingPlanInfo? _today;
  List<TrainingPlanInfo> _all = [];
  WeekSession _todaySession = const WeekSession(exists: false);
  final Map<int, WeekSession> _otherSessions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _today = await _plans.getTodayPlan();
    _all = await _plans.getPlans();
    _otherSessions.clear();
    if (_today != null) {
      _todaySession = await _sessions.getThisWeekSession(_today!.id);
    } else {
      _todaySession = const WeekSession(exists: false);
    }
    for (final t in _all.where((p) => p.id != _today?.id)) {
      _otherSessions[t.id] = await _sessions.getThisWeekSession(t.id);
    }
    if (mounted) setState(() => _loading = false);
  }

  String? _status(int dayId) {
    final today = DateTime.now().weekday;
    if (dayId < today) return 'late';
    if (dayId > today) return 'early';
    return null;
  }

  Future<void> _openSession(int planId) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => SessionScreen(planId: planId)));
    _load();
  }

  Future<void> _openEdit(int sessionId) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditSessionScreen(sessionId: sessionId)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final others = _all.where((p) => p.id != _today?.id).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('InspireFit')),
      drawer: const AppDrawer(current: HomeScreen.route),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
                  _todayCard(),
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Center(
                      child: Text('Treinos para fazer atrasado ou adiantar',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    for (final t in others) _otherCard(t),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _todayCard() {
    if (_all.isEmpty) {
      return _bigBox(
        color: AppColors.blue,
        onTap: () =>
            Navigator.pushReplacementNamed(context, FichasScreen.route),
        child: const Text('Você precisa criar uma ficha',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: AppColors.blue)),
      );
    }

    if (_today == null) {
      return _bigBox(
        color: AppColors.border,
        child: const Text('Sem treinos para hoje, bom descanso.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: Colors.white)),
      );
    }

    if (_todaySession.exists) {
      return _bigBox(
        color: AppColors.greenBright,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'O ${_today!.trainingName} de ${_today!.dayName} foi concluído hoje!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenBright)),
            if (_todaySession.sessionId != null)
              TextButton.icon(
                onPressed: () => _openEdit(_todaySession.sessionId!),
                icon: const Icon(Icons.edit, size: 14,
                    color: AppColors.greenBright),
                label: const Text('editar',
                    style: TextStyle(color: AppColors.greenBright)),
              ),
          ],
        ),
      );
    }

    return _bigBox(
      color: AppColors.blue,
      onTap: () => _openSession(_today!.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Treino de hoje:',
              style: TextStyle(fontSize: 20, color: AppColors.blue)),
          const SizedBox(height: 8),
          Text(_today!.trainingName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue)),
          Text(_today!.dayName,
              style: const TextStyle(fontSize: 16, color: AppColors.blue)),
        ],
      ),
    );
  }

  Widget _bigBox(
      {required Color color, required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
        child: Center(child: child),
      ),
    );
  }

  Widget _otherCard(TrainingPlanInfo t) {
    final session = _otherSessions[t.id];
    final done = session?.exists ?? false;
    final status = _status(t.dayId);

    Color color;
    if (done) {
      color = AppColors.greenBright;
    } else if (status == 'late') {
      color = AppColors.red;
    } else if (status == 'early') {
      color = AppColors.orange;
    } else {
      color = AppColors.textFaint;
    }

    String? badge;
    if (done) {
      badge = 'concluído';
    } else if (status == 'late') {
      badge = 'atrasado';
    } else if (status == 'early') {
      badge = 'adiantar';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: done
            ? (session?.sessionId != null
                ? () => _openEdit(session!.sessionId!)
                : null)
            : () => _openSession(t.id),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(t.trainingName, style: TextStyle(color: color)),
              const SizedBox(width: 12),
              Text(t.dayName,
                  style: TextStyle(color: color, fontSize: 13)),
              if (badge != null) ...[
                const SizedBox(width: 12),
                Text(badge,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
              if (done && session?.sessionId != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.edit, size: 16, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
