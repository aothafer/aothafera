import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'challenge_provider.dart';
import 'notification_service.dart';
import 'route_observer.dart';
import 'welcome_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
  );
  await NotificationService.instance.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ChallengeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عُذافِرة',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorObservers: [routeObserver],
      // الواجهة عربي، فالاتجاه من اليمين لليسار
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const WelcomeScreen(),
    );
  }
}
