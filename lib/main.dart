import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/business_screen.dart';
import 'screens/main_shell.dart';
import 'services/ad_gate.dart';
import 'services/ai_service.dart';
import 'services/premium_service.dart';
import 'services/reminder_service.dart';
import 'services/settings.dart';
import 'services/store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final settings = AppSettings();
  final store = Store();
  final premium = PremiumService();
  await Future.wait([settings.load(), store.load(), premium.load()]);
  AdGate.init().ignore();
  ReminderService.init().ignore();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: premium),
      Provider.value(value: AiService(settings)),
    ],
    child: const QuickOfficeApp(),
  ));
}

class QuickOfficeApp extends StatelessWidget {
  const QuickOfficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return MaterialApp(
      title: 'QuickOffice',
      navigatorKey: AdGate.navigatorKey,
      scaffoldMessengerKey: AdGate.messengerKey,
      debugShowCheckedModeBanner: false,
      themeMode: s.themeMode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: s.onboardingDone ? const MainShell() : const BusinessScreen(firstRun: true),
    );
  }
}
