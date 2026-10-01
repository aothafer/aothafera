import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'challenge_provider.dart';
import 'home_screen.dart';
import 'notification_service.dart';
import 'route_observer.dart';
import 'welcome_screen.dart';
import 'theme.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
const _alarmIntentChannel = MethodChannel(
  'com.example.challenge_tracker/notification_settings',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
  );
  await NotificationService.instance.init();
  final challengeProvider = ChallengeProvider();
  await challengeProvider.load();
  runApp(
    ChangeNotifierProvider.value(
      value: challengeProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _alarmIntentChannel.setMethodCallHandler(_handleAlarmIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final challengeId = await _alarmIntentChannel.invokeMethod<String>(
          'getPendingChallengeId',
        );
        if (challengeId != null) _openChallengeProgress(challengeId);
      } on PlatformException catch (error) {
        debugPrint('Could not read alarm launch intent: ${error.message}');
      }
    });
  }

  Future<void> _handleAlarmIntent(MethodCall call) async {
    if (call.method == 'openChallengeProgress' && call.arguments is String) {
      _openChallengeProgress(call.arguments as String);
    }
  }

  void _openChallengeProgress(String challengeId) {
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(initialChallengeId: challengeId),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
