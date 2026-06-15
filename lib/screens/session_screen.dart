import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../repositories/training_plan_repository.dart';
import '../repositories/training_session_repository.dart';
import '../theme/app_theme.dart';

class _Serie {
  final double reps;
  final double weight;
  const _Serie(this.reps, this.weight);
}

/// Registro de uma sessão de treino, navegando exercício por exercício,
/// com timer de descanso. Espelha `TrainingSessionView.vue`.
class SessionScreen extends StatefulWidget {
  final int planId;
  const SessionScreen({super.key, required this.planId});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  static const _timerDuration = 120;

  TrainingPlanRepository get _plans => context.read<TrainingPlanRepository>();
  TrainingSessionRepository get _sessions =>
      context.read<TrainingSessionRepository>();

  List<PlanExercise> _exercises = [];
  late List<List<_Serie>> _series;
  int _current = 0;
  bool _saving = false;

  final _repsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _repsError;
  String? _weightError;

  int _timer = _timerDuration;
  bool _timerRunning = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _plans.getPlanExercises(widget.planId);
    setState(() {
      _exercises = data;
      _series = List.generate(data.length, (_) => <_Serie>[]);
    });
  }

  void _addSerie() {
    setState(() {
      _repsError = null;
      _weightError = null;
    });
    final reps = double.tryParse(_repsCtrl.text.replaceAll(',', '.'));
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    var valid = true;
    if (reps == null || reps < 1) {
      setState(() => _repsError = 'Informe as repetições (mín. 1)');
      valid = false;
    }
    if (weight == null || weight < 0) {
      setState(() => _weightError = 'Informe o peso');
      valid = false;
    }
    if (!valid) return;
    setState(() {
      _series[_current].add(_Serie(reps!, weight!));
      _repsCtrl.clear();
      _weightCtrl.clear();
    });
  }

  void _removeSerie(int i) =>
      setState(() => _series[_current].removeAt(i));

  void _go(int delta) {
    final next = _current + delta;
    if (next < 0 || next >= _exercises.length) return;
    setState(() {
      _current = next;
      _repsError = null;
      _weightError = null;
      _repsCtrl.clear();
      _weightCtrl.clear();
    });
  }

  // --- Timer ---
  void _toggleTimer() {
    if (_timerRunning) {
      _ticker?.cancel();
      setState(() => _timerRunning = false);
    } else {
      if (_timer == 0) _timer = _timerDuration;
      setState(() => _timerRunning = true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _timer--;
          if (_timer <= 0) {
            _timer = 0;
            _ticker?.cancel();
            _timerRunning = false;
          }
        });
      });
    }
  }

  void _resetTimer() {
    _ticker?.cancel();
    setState(() {
      _timerRunning = false;
      _timer = _timerDuration;
    });
  }

  String get _timerDisplay {
    final m = _timer ~/ 60;
    final s = (_timer % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canSubmit => _series.any((s) => s.isNotEmpty);

  Future<void> _requestSubmit() async {
    final empty = <String>[];
    for (var i = 0; i < _exercises.length; i++) {
      if (_series[i].isEmpty) empty.add(_exercises[i].exerciseName);
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(empty: empty),
    );
    if (ok == true) _submit();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final executions = <ExecutionInput>[];
      for (var i = 0; i < _exercises.length; i++) {
        final series = _series[i];
        if (series.isEmpty) continue;
        final setsDone = series.length;
        final totalReps = series.fold<double>(0, (a, s) => a + s.reps);
        final avgReps = (totalReps / setsDone).roundToDouble();
        // Média ponderada de peso pelos reps (igual ao app Vue).
        final weightedWeight =
            series.fold<double>(0, (a, s) => a + s.weight * s.reps) / totalReps;
        final avgWeight =
            double.parse(weightedWeight.toStringAsFixed(1));
        executions.add(ExecutionInput(
          trainingPlanExerciseId: _exercises[i].id,
          setsDone: setsDone,
          reps: avgReps,
          weight: avgWeight,
        ));
      }
      await _sessions.createSession(
        planId: widget.planId,
        performedDate: DateTime.now(),
        executions: executions,
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exercises.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final series = _series[_current];
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          children: [
            Text('${_current + 1} / ${_exercises.length}',
                style: const TextStyle(color: AppColors.textFaint)),
            const SizedBox(height: 4),
            Text(_exercises[_current].exerciseName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _seriesTable(series),
            const SizedBox(height: 20),
            _inputs(),
            const SizedBox(height: 16),
            _navRow(),
            const SizedBox(height: 16),
            _timerBox(),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    _canSubmit ? AppColors.green : AppColors.surfaceAlt,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size.fromHeight(0),
              ),
              onPressed: _canSubmit && !_saving ? _requestSubmit : null,
              child: Text(_saving ? 'Enviando...' : 'Finalizar treino',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seriesTable(List<_Serie> series) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: _Th('Série')),
            Expanded(child: _Th('Repetições')),
            Expanded(child: _Th('Peso (kg)')),
            SizedBox(width: 32),
          ],
        ),
        const Divider(color: AppColors.border),
        if (series.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nenhuma série registrada',
                style: TextStyle(color: AppColors.textFaint)),
          ),
        for (var i = 0; i < series.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                    child: Text('${i + 1}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: AppColors.textMuted))),
                Expanded(
                    child: Text(_n(series[i].reps),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text(_n(series[i].weight),
                        textAlign: TextAlign.center)),
                SizedBox(
                  width: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close,
                        size: 16, color: AppColors.red),
                    onPressed: () => _removeSerie(i),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${series.length} série(s)',
              style: const TextStyle(
                  color: AppColors.textFaint, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _inputs() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _numField('Repetições', _repsCtrl, _repsError),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _numField('Peso (kg)', _weightCtrl, _weightError),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14)),
            onPressed: _addSerie,
            child: const Text('+ Série'),
          ),
        ),
      ],
    );
  }

  Widget _numField(String label, TextEditingController ctrl, String? error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onSubmitted: (_) => _addSerie(),
          decoration: InputDecoration(
            isDense: true,
            errorText: error,
            fillColor: AppColors.surfaceAlt,
          ),
        ),
      ],
    );
  }

  Widget _navRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _navBtn(Icons.arrow_back, _current > 0 ? () => _go(-1) : null),
        const Text('navegar exercícios',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
        _navBtn(Icons.arrow_forward,
            _current < _exercises.length - 1 ? () => _go(1) : null),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Icon(icon,
              color: onTap == null ? AppColors.textFaint : Colors.white),
        ),
      ),
    );
  }

  Widget _timerBox() {
    final color = _timer <= 10 && _timer > 0
        ? AppColors.red
        : (_timer == 0 ? AppColors.textFaint : Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Descanso',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textFaint)),
              Text(_timerDisplay,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [],
                      letterSpacing: 3,
                      color: color)),
            ],
          ),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _timerRunning
                        ? const Color(0xFFCA8A04)
                        : AppColors.green),
                onPressed: _toggleTimer,
                child: Text(_timerRunning
                    ? 'Pausar'
                    : _timer == _timerDuration
                        ? 'Iniciar'
                        : _timer == 0
                            ? 'Reiniciar'
                            : 'Continuar'),
              ),
              if (_timer != _timerDuration) ...[
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceAlt),
                  icon: const Icon(Icons.replay),
                  onPressed: _resetTimer,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 13));
}

class _ConfirmSheet extends StatelessWidget {
  final List<String> empty;
  const _ConfirmSheet({required this.empty});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Concluir treino?',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (empty.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Exercícios sem registro:',
                        style: TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    for (final n in empty)
                      Text('· $n',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Concluir assim mesmo'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: AppColors.surfaceAlt,
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
