import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../repositories/training_session_repository.dart';
import '../theme/app_theme.dart';

class EditSessionScreen extends StatefulWidget {
  final int sessionId;
  const EditSessionScreen({super.key, required this.sessionId});

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  TrainingSessionRepository get _sessions =>
      context.read<TrainingSessionRepository>();

  bool _loading = true;
  bool _saving = false;
  List<ExecutionInfo> _executions = [];
  final Map<int, TextEditingController> _setsCtrls = {};
  final Map<int, TextEditingController> _repsCtrls = {};
  final Map<int, TextEditingController> _weightCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._setsCtrls.values, ..._repsCtrls.values, ..._weightCtrls.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final execs = await _sessions.getSessionExecutions(widget.sessionId);
    for (final e in execs) {
      _setsCtrls[e.id] = TextEditingController(text: _n(e.setsDone));
      _repsCtrls[e.id] = TextEditingController(text: _n(e.reps));
      _weightCtrls[e.id] = TextEditingController(text: _n(e.weight));
    }
    setState(() {
      _executions = execs;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = _executions.map((e) {
        return ExecutionInfo(
          id: e.id,
          trainingPlanExerciseId: e.trainingPlanExerciseId,
          exerciseName: e.exerciseName,
          setsDone: int.tryParse(_setsCtrls[e.id]!.text.trim()),
          reps: double.tryParse(_repsCtrls[e.id]!.text.replaceAll(',', '.')),
          weight:
              double.tryParse(_weightCtrls[e.id]!.text.replaceAll(',', '.')),
        );
      }).toList();
      await _sessions.updateExecutions(updated);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir treino registrado?'),
        content: const Text(
            'Esta sessão e suas execuções serão apagadas permanentemente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _sessions.deleteSession(widget.sessionId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar treino'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
            onPressed: _deleteSession,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                for (final e in _executions) _execCard(e),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Salvando...' : 'Salvar alterações',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }

  Widget _execCard(ExecutionInfo e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDim),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.exerciseName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field('Séries', _setsCtrls[e.id]!)),
              const SizedBox(width: 8),
              Expanded(child: _field('Reps', _repsCtrls[e.id]!)),
              const SizedBox(width: 8),
              Expanded(child: _field('Peso (kg)', _weightCtrls[e.id]!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
              isDense: true, fillColor: AppColors.surfaceAlt),
        ),
      ],
    );
  }

  String _n(num? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}
