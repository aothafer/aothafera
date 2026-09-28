import 'dart:math';

import 'package:flutter/material.dart';

import 'add_challenge_screen.dart';
import 'home_screen.dart';
import 'quotes.dart';
import 'route_observer.dart';
import 'theme.dart';

/// صورة خلفية شاشة الترحيب (الطولية)
const String kWelcomeBackground = 'assets/images/welcome_bg.jpg';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _controller;
  Quote _quote = kQuotes[Random().nextInt(kQuotes.length)];

  void _pickNewQuote() {
    if (kQuotes.length < 2) return; // عشان الاقتباس ميتكررش
    Quote next;
    do {
      next = kQuotes[Random().nextInt(kQuotes.length)];
    } while (identical(next, _quote));
    setState(() => _quote = next);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  /// بترجعي هنا من شاشة تانية (زي "تحدياتي") → اقتباس جديد
  @override
  void didPopNext() => _pickNewQuote();

  /// بتظهر العنصر تدريجيًا في جزء معين من الأنيميشن (من 0 لـ 1)
  Animation<double> _fade(double from, double to) => CurvedAnimation(
        parent: _controller,
        curve: Interval(from, to, curve: Curves.easeOut),
      );

  /// الاقتباس مكتوب عادي من غير إطار، وبظل خفيف عشان يبان
  Widget _quoteText() {
    final shadow = [
      Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 12),
    ];
    final hasAttribution = _quote.author != null;
    return Column(
      children: [
        Text(
          '«${_quote.text}»',
          textAlign: TextAlign.center,
          style: quoteTextStyle(size: 21).copyWith(shadows: shadow),
        ),
        if (hasAttribution) ...[
          const SizedBox(height: 10),
          Text(
            _quote.attribution,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.cream.withValues(alpha: 0.75),
                  shadows: shadow,
                ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1) اللوحة واضحة، وبتكبر ببطء
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + 0.08 * _controller.value,
              child: child,
            ),
            child: Image.asset(
              kWelcomeBackground,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // 2) تعتيم خفيف فوق وتحت (الوسط سايبينه عشان الأفق المضيء)
          FadeTransition(
            opacity: _fade(0.25, 0.6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bg.withValues(alpha: 0.35),
                    AppColors.bg.withValues(alpha: 0.0),
                    AppColors.bg.withValues(alpha: 0.0),
                    AppColors.bg.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.3, 0.72, 1.0],
                ),
              ),
            ),
          ),

          // 3) الاسم والجملة والاقتباس في المساحة الغامقة فوق، والأزرار تحت
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 36),
                          FadeTransition(
                            opacity: _fade(0.3, 0.55),
                            child: Column(
                              children: [
                                Text(
                                  'عُذافِرة',
                                  style: textTheme.headlineMedium
                                      ?.copyWith(fontSize: 52, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          FadeTransition(
                            opacity: _fade(0.5, 0.75),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: KeyedSubtree(
                                key: ValueKey(_quote.text),
                                child: _quoteText(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _fade(0.75, 1.0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            ),
                            child: const Text('مرمى الهدف'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  AppColors.bg.withValues(alpha: 0.55),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddChallengeScreen(),
                              ),
                            ),
                            child: const Text('هدفٌ جديد ؟'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
