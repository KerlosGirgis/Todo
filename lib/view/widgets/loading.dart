import 'package:flutter/material.dart';
import 'package:todo/core/utils/loading_utils.dart';

import '../../core/extensions/theme_extensions.dart';

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.1).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 50,
      ),
    ]).animate(_controller);

    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final shortestSide = size.shortestSide;

    final iconSize = shortestSide * 0.3;
    final containerPadding = shortestSide * 0.1;
    final progressWidth = shortestSide * 0.5;

    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  child: Image.asset(
                    'assets/icon.png',
                    width: iconSize,
                    height: iconSize,
                  ),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          padding: EdgeInsets.all(containerPadding),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.cardBackground,
                            boxShadow: [
                              BoxShadow(
                                color: context
                                    .colors.floatingActionButtonBackground
                                    .withValues(alpha: 0.2),
                                blurRadius: shortestSide * 0.08,
                                spreadRadius: shortestSide * 0.02,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: shortestSide * 0.12),
                SizedBox(
                  width: progressWidth.clamp(160, 320),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        backgroundColor: context.colors.cardBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.floatingActionButtonBackground,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      SizedBox(height: shortestSide * 0.06),
                      SizedBox(
                        width: progressWidth * .85,
                        child: Text(
                          LoadingUtils.getRandomMessage(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.subtitle,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                            fontSize: shortestSide * 0.03,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
