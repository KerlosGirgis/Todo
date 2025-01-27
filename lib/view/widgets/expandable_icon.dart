import 'package:flutter/material.dart';

class ExpandableIcon extends StatefulWidget {
  final VoidCallback onClicked;
  final double width, height;
  final Color iconColor;
  final int animationSpeed;

  const ExpandableIcon({
    super.key,
    required this.onClicked,
    required this.width,
    required this.height,
    required this.iconColor,
    this.animationSpeed = 500,
  });

  @override
  State<ExpandableIcon> createState() => _ExpandableIconState();
}

class _ExpandableIconState extends State<ExpandableIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.animationSpeed),
      vsync: this,
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleAnimation() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    widget.onClicked();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        _toggleAnimation();
      },
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: _animation,
        size: widget.height * 0.7,
        color: widget.iconColor,
      ),
    );

    /*GestureDetector(
      onTap: _toggleAnimation,
      child: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: _animation,
        size: widget.height * 0.7,
        color: widget.iconColor,
      ),
    );*/
  }
}
