import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'ui/park_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ParkUApp(apiService: ApiService()));
}

class ParkUApp extends StatelessWidget {
  final ApiService apiService;
  const ParkUApp({super.key, required this.apiService});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ParkU - Universidad Santo Tomás',
    debugShowCheckedModeBanner: false,
    theme: parkTheme(),
    home: LoginScreen(apiService: apiService),
  );
}
