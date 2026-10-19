import 'dart:async';

import 'package:flutter/material.dart';

/// Rises into place and fades in when it's first built, after [delay], as the
/// profile page's sections do when it opens. Whether it runs is up to its
/// parent, through [animate], rather than to how long ago a list was first
/// laid out, so items added later can rise in too.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

  /// The gap between neighbours rising in one after another.
  static const stagger = Duration(milliseconds: 83);

  final Widget child;
  final Duration delay;

  /// Whether to rise in at all, rather than just showing [child]. Only read
  /// when it's first built.
  final bool animate;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: widget.animate ? 0 : 1,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _timer = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Transform.translate(
          offset: Offset(0, 32 * (1 - Curves.easeOutCubic.transform(value))),
          child:
              Opacity(opacity: Curves.easeOut.transform(value), child: child),
        );
      },
      child: widget.child,
    );
  }
}
