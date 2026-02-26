import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Vibrant dark gradient
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8121DA), // Deep Purple
              Color(0xFF4C22DC), // Deep Indigo
              Color(0xFF1E58E9), // Vibrant Blue
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeIn,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.event_available_rounded, size: 90, color: Colors.white),
                  SizedBox(height: 24),
                  Text(
                    "AI Schedule Generator",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Merapikan Harimu",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
