import 'package:flutter/material.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';

class CustomSplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const CustomSplashScreen({super.key, required this.onFinish});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.8, curve: Curves.easeIn)),
    );

    _controller.forward();

    // Smoother, more professional transition
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache the logo to prevent a white flash or delay in image rendering
    precacheImage(const AssetImage('assets/images/tarifflogo.png'), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: TariffColors.amberPending.withValues(alpha: isDark ? 0.05 : 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: TariffColors.amberPending.withValues(alpha: isDark ? 0.1 : 0.05),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 120, // Perfectly controlled size
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'TARIFFGUARD AI',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1565C0),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'INTELLIGENCE & COMPLIANCE',
                      style: TextStyle(
                        color: isDark ? TariffColors.textMuted : Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
