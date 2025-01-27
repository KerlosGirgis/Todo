import 'package:flutter/material.dart';

import 'expandable_icon.dart';
/// A controller for programmatic control of ExpandableMenu.


/// The main ExpandableMenu widget that supports animation and an expandable menu list.
class ExpandableMenu extends StatefulWidget {
  final double width, height;
  final int animationSpeed;
  final List<Widget> items;
  final Color iconColor;

  const ExpandableMenu({
    super.key,
    this.width = 70.0,
    this.height = 70.0,
    this.animationSpeed = 800,
    required this.items,
    this.iconColor = Colors.white,
  });

  @override
  State<ExpandableMenu> createState() => ExpandableMenuState();
}

class ExpandableMenuState extends State<ExpandableMenu> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ExpandableIcon(
          onClicked: () => setState(() => _isExpanded = !_isExpanded),
          width: widget.width,
          height: widget.height,
          iconColor: widget.iconColor,
          animationSpeed: widget.animationSpeed,
        ),
        AnimatedContainer(
          width: _isExpanded ? widget.width * 5 : 0,
          height: widget.height,
          duration: Duration(milliseconds: widget.animationSpeed),
          curve: Curves.fastLinearToSlowEaseIn,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: widget.items,
          ),
        ),
      ],
    );
  }
}

