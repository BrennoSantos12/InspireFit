import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/models.dart';
import '../repositories/training_plan_repository.dart';
import '../theme/app_theme.dart';
import 'create_plan_screen.dart';
import 'edit_plan_screen.dart';

/// Lista de fichas com editar/excluir. Espelha `FichaView.vue`.
class FichasScreen extends StatefulWidget {
  static const route = '/fichas';
  const FichasScreen({super.key});

  @override
  State<FichasScreen> createState() => _FichasScreenState();
}

class _FichasScreenState extends State<FichasScreen> {
  late Future<List<TrainingPlanInfo>> _future;

  TrainingPlanRepository get _repo => context.read<TrainingPlanRepository>();

  @override
  void initState() {
    super.initState();
    _future = _repo.getPlans();
  }

  void _reload() => setState(() => _future = _repo.getPlans());

  Future<void> _confirmDelete(TrainingPlanInfo plan) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeleteSheet(plan: plan),
    );
    if (ok == true) {
      await _repo.deletePlan(plan.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fichas')),
      drawer: const AppDrawer(current: FichasScreen.route),
      body: FutureBuilder<List<TrainingPlanInfo>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final plans = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (plans.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('Nenhuma ficha criada ainda.',
                        style: TextStyle(color: AppColors.textFaint)),
                  ),
                ),
              for (final plan in plans) _planCard(plan),
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreatePlanScreen()),
                  );
                  _reload();
                },
                child: const Text('+ Criar ficha',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _planCard(TrainingPlanInfo plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDim),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.trainingName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 2),
                Text(plan.dayName,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => EditPlanScreen(planId: plan.id)),
              );
              _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
            onPressed: () => _confirmDelete(plan),
          ),
        ],
      ),
    );
  }
}

class _DeleteSheet extends StatefulWidget {
  final TrainingPlanInfo plan;
  const _DeleteSheet({required this.plan});

  @override
  State<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends State<_DeleteSheet> {
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
            const Text('Excluir ficha?',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${widget.plan.trainingName} — ${widget.plan.dayName}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            const Text('Todo o histórico de treinos desta ficha será apagado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sim, excluir'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surfaceAlt,
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
