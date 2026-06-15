import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/training_plan_repository.dart';
import '../theme/app_theme.dart';

class PlanFormScreen extends StatefulWidget {
  final int? planId;
  const PlanFormScreen({super.key, this.planId});

  bool get isEditing => planId != null;

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  CatalogRepository get _catalog => context.read<CatalogRepository>();
  TrainingPlanRepository get _plans => context.read<TrainingPlanRepository>();

  bool _loading = true;
  bool _saving = false;

  List<Day> _days = [];
  List<Training> _trainings = [];
  List<Exercise> _exercises = [];

  int? _dayId;
  int? _trainingId;
  final Set<int> _selected = {};

  Set<String> _usedDayNames = {};
  Set<String> _usedTrainingNames = {};
  String? _ownDayName;
  String? _ownTrainingName;

  final _searchCtrl = TextEditingController();
  String _filterType = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _days = await _catalog.getDays();
    _trainings = await _catalog.getTrainings();
    _exercises = await _catalog.getExercises();

    final existing = await _plans.getPlans();

    if (widget.isEditing) {
      final plan = await _plans.getPlan(widget.planId!);
      if (plan != null) {
        _dayId = plan.dayId;
        _trainingId = plan.trainingId;
        _ownDayName = plan.dayName;
        _ownTrainingName = plan.trainingName;
      }
      final planExercises = await _plans.getPlanExercises(widget.planId!);
      _selected.addAll(planExercises.map((e) => e.exerciseId));
    }

    _usedDayNames = existing
        .where((p) => p.id != widget.planId)
        .map((p) => p.dayName)
        .toSet();
    _usedTrainingNames = existing
        .where((p) => p.id != widget.planId)
        .map((p) => p.trainingName)
        .toSet();

    setState(() => _loading = false);
  }

  Future<void> _fetchExercises() async {
    _exercises = await _catalog.getExercises(
      name: _searchCtrl.text,
      type: _filterType.isEmpty ? null : _filterType,
    );
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _fetchExercises);
  }

  bool get _canSubmit =>
      _dayId != null && _trainingId != null && _selected.isNotEmpty;

  Future<void> _save() async {
    if (!_canSubmit) return;
    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await _plans.updatePlan(
          planId: widget.planId!,
          trainingId: _trainingId!,
          dayId: _dayId!,
          exerciseIds: _selected.toList(),
        );
      } else {
        await _plans.createPlan(
          trainingId: _trainingId!,
          dayId: _dayId!,
          exerciseIds: _selected.toList(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isEditing ? 'Editar ficha' : 'Criar ficha')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _label('Dia da semana'),
                _dayDropdown(),
                const SizedBox(height: 16),
                _label('Treino'),
                _trainingDropdown(),
                const SizedBox(height: 20),
                _label('Exercícios'),
                _filters(),
                const SizedBox(height: 8),
                ..._exerciseList(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_selected.length} exercício(s) selecionado(s)',
                        style: TextStyle(
                            fontSize: 13,
                            color: _selected.isEmpty
                                ? AppColors.red
                                : AppColors.textMuted)),
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Limpar todos',
                          style: TextStyle(color: AppColors.red)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _canSubmit ? AppColors.green : AppColors.surfaceAlt,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _canSubmit && !_saving ? _save : null,
                  child: Text(_saving ? 'Salvando...' : 'Salvar ficha',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      );

  Widget _dayDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _dayId,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      hint: const Text('-- Selecione o dia --',
          style: TextStyle(color: AppColors.textFaint)),
      items: _days.map((d) {
        final used = _usedDayNames.contains(d.name) && d.name != _ownDayName;
        return DropdownMenuItem(
          value: d.id,
          enabled: !used,
          child: Text('${d.name}${used ? ' (em uso)' : ''}',
              style: TextStyle(
                  color: used ? AppColors.textFaint : Colors.white)),
        );
      }).toList(),
      onChanged: (v) => setState(() => _dayId = v),
    );
  }

  Widget _trainingDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _trainingId,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      hint: const Text('-- Selecione o treino --',
          style: TextStyle(color: AppColors.textFaint)),
      items: _trainings.map((t) {
        final used = _usedTrainingNames.contains(t.name) &&
            t.name != _ownTrainingName;
        return DropdownMenuItem(
          value: t.id,
          enabled: !used,
          child: Text('${t.name}${used ? ' (em uso)' : ''}',
              style: TextStyle(
                  color: used ? AppColors.textFaint : Colors.white)),
        );
      }).toList(),
      onChanged: (v) => setState(() => _trainingId = v),
    );
  }

  Widget _filters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar por nome...',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _filterType,
          dropdownColor: AppColors.surface,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: '', child: Text('Todos')),
            DropdownMenuItem(value: 'superior', child: Text('Superior')),
            DropdownMenuItem(value: 'inferior', child: Text('Inferior')),
            DropdownMenuItem(value: 'posterior', child: Text('Posterior')),
          ],
          onChanged: (v) {
            setState(() => _filterType = v ?? '');
            _fetchExercises();
          },
        ),
      ],
    );
  }

  List<Widget> _exerciseList() {
    if (_exercises.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
              child: Text('Nenhum exercício encontrado.',
                  style: TextStyle(color: AppColors.textFaint))),
        ),
      ];
    }
    return _exercises.map((ex) {
      final selected = _selected.contains(ex.id);
      return InkWell(
        onTap: () => setState(() {
          if (selected) {
            _selected.remove(ex.id);
          } else {
            _selected.add(ex.id);
          }
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            border: Border.all(
                color: selected ? AppColors.border : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                color:
                    selected ? AppColors.greenBright : AppColors.textFaint,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(ex.name,
                      style: const TextStyle(fontSize: 14))),
              Text(ex.type,
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 12)),
            ],
          ),
        ),
      );
    }).toList();
  }
}
