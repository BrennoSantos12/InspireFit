import 'package:flutter/material.dart';

import 'plan_form_screen.dart';

class EditPlanScreen extends StatelessWidget {
  final int planId;
  const EditPlanScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) => PlanFormScreen(planId: planId);
}
