import 'package:flutter/material.dart';

import 'screens/fichas_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'theme/app_theme.dart';

class InspireFitApp extends StatelessWidget {
  const InspireFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InspireFit',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: HomeScreen.route,
      routes: {
        HomeScreen.route: (_) => const HomeScreen(),
        FichasScreen.route: (_) => const FichasScreen(),
        ReportScreen.route: (_) => const ReportScreen(),
      },
    );
  }
}

/// Menu lateral equivalente ao hamburger do app antigo (sem login/perfil).
class AppDrawer extends StatelessWidget {
  final String current;
  const AppDrawer({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'InspireFit',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.greenBright,
              ),
            ),
            const SizedBox(height: 24),
            _item(context, 'Início', Icons.home_outlined, HomeScreen.route),
            _item(context, 'Treinos', Icons.fitness_center_outlined,
                FichasScreen.route),
            _item(context, 'Relatórios', Icons.bar_chart_outlined,
                ReportScreen.route),
          ],
        ),
      ),
    );
  }

  Widget _item(
      BuildContext context, String label, IconData icon, String route) {
    final selected = route == current;
    return ListTile(
      leading: Icon(icon,
          color: selected ? AppColors.greenBright : Colors.white),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.greenBright : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (!selected) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }
}
