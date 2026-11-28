import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A page's margins either side of what it shows: clear of a camera cutout
/// on a phone turned on its side, and on a large screen, wide enough that
/// what's between them is no wider than [maxWidth], in the middle.
EdgeInsets pageGutters(BuildContext context, {required double maxWidth}) {
  final padding = MediaQuery.paddingOf(context);
  final centred = (MediaQuery.sizeOf(context).width - maxWidth) / 2;
  return EdgeInsets.only(
    left: math.max(16 + padding.left, centred),
    right: math.max(16 + padding.right, centred),
  );
}
