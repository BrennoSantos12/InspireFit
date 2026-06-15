import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/report_models.dart';
import '../repositories/report_repository.dart';
import '../repositories/training_plan_repository.dart';
import '../repositories/training_session_repository.dart';
import '../theme/app_theme.dart';

class ReportScreen extends StatefulWidget {
  static const route = '/report';
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ReportRepository get _reports => context.read<ReportRepository>();
  TrainingPlanRepository get _plans => context.read<TrainingPlanRepository>();
  TrainingSessionRepository get _sessions =>
      context.read<TrainingSessionRepository>();

  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();

  bool _loading = false;
  List<PlanAdherence> _adherence = [];
  int? _expanded;
  final Map<int, List<ExerciseProgress>> _progress = {};

  @override
  void initState() {
    super.initState();
    _initRange();
  }

  Future<void> _initRange() async {
    final plans = await _plans.getPlans();
    String? earliest;
    for (final p in plans) {
      final d = await _sessions.getFirstDate(p.id);
      if (d != null && (earliest == null || d.compareTo(earliest) < 0)) {
        earliest = d;
      }
    }
    if (earliest != null) {
      final parts = earliest.split('-');
      _start = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    _adherence = await _reports.getPlanAdherence(_start, _end);
    _progress.clear();
    _expanded = null;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(int planId) async {
    if (_expanded == planId) {
      setState(() => _expanded = null);
      return;
    }
    setState(() => _expanded = planId);
    if (!_progress.containsKey(planId)) {
      final p = await _reports.getExerciseProgress(planId, _start, _end);
      if (mounted) setState(() => _progress[planId] = p);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
      _loadReport();
    }
  }

  String _fmtBr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  int _pct(PlanAdherence a) {
    final denom = a.plannedTotal > a.doneTotal ? a.plannedTotal : a.doneTotal;
    if (denom == 0) return 0;
    return ((a.doneTotal / denom) * 100).round();
  }

  Color _pctColor(int pct) {
    if (pct >= 80) return AppColors.greenBright;
    if (pct >= 50) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      drawer: const AppDrawer(current: ReportScreen.route),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(child: _dateBtn('Início', _start, () => _pickDate(true))),
                const SizedBox(width: 12),
                Expanded(child: _dateBtn('Fim', _end, () => _pickDate(false))),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _adherence.isEmpty
                    ? const Center(
                        child: Text('Nenhuma ficha para relatar.',
                            style: TextStyle(color: AppColors.textFaint)))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children:
                            [for (final a in _adherence) _adherenceCard(a)],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _dateBtn(String label, DateTime value, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onPressed: onTap,
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textFaint)),
          Text(_fmtBr(value),
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _adherenceCard(PlanAdherence a) {
    final pct = _pct(a);
    final color = _pctColor(pct);
    final expanded = _expanded == a.trainingPlanId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDim),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggle(a.trainingPlanId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.trainingName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(a.dayName,
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      Text('$pct%',
                          style: TextStyle(
                              color: color,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Icon(
                          expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _chip('Certo', a.doneRightDay, AppColors.greenBright),
                      _chip('Adiantado', a.doneEarly, AppColors.orange),
                      _chip('Dia errado', a.doneWrongDay, AppColors.blue),
                      _chip('Não feito', a.notDone, AppColors.red),
                      _chip('Planejado', a.plannedTotal,
                          AppColors.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _progressSection(a.trainingPlanId),
        ],
      ),
    );
  }

  Widget _chip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value',
          style: TextStyle(color: color, fontSize: 11)),
    );
  }

  Widget _progressSection(int planId) {
    final list = _progress[planId];
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sem exercícios.',
            style: TextStyle(color: AppColors.textFaint)),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderDim)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [for (final ex in list) _progressRow(ex)],
      ),
    );
  }

  Widget _progressRow(ExerciseProgress ex) {
    final freqTotal = ex.timesPerformed + ex.timesSkipped;
    final freqPct =
        freqTotal == 0 ? 0 : ((ex.timesPerformed / freqTotal) * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(ex.exerciseName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14))),
              Text('${ex.timesPerformed}/$freqTotal · $freqPct%',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          _statLine('Primeira', ex.firstExecution),
          _statLine('Melhor', ex.bestExecution),
          _statLine('Última', ex.lastExecution),
          if (ex.improvementSummary != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(ex.improvementSummary!,
                      style: TextStyle(
                          fontSize: 12,
                          color: _improvementColor(
                              ex.improvementPercentage))),
                ),
                if (ex.improvementPercentage != null)
                  Text(
                      '${ex.improvementPercentage! > 0 ? '+' : ''}${ex.improvementPercentage}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _improvementColor(
                              ex.improvementPercentage))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _improvementColor(double? pct) {
    if (pct == null || pct == 0) return AppColors.textFaint;
    return pct > 0 ? AppColors.greenBright : AppColors.red;
  }

  Widget _statLine(String label, ExecutionStats? s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
              width: 64,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 12))),
          Expanded(
            child: Text(_fmtExec(s),
                style: const TextStyle(fontSize: 12)),
          ),
          if (s != null)
            Text(s.performedDate,
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: 11)),
        ],
      ),
    );
  }

  String _fmtExec(ExecutionStats? s) {
    if (s == null) return '—';
    final parts = <String>[];
    if (s.setsDone != null) parts.add('${s.setsDone}x');
    if (s.reps != null) parts.add('${_n(s.reps!)} reps');
    if (s.weight != null) parts.add('${_n(s.weight!)}kg');
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
