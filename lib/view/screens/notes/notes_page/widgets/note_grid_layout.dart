/// How the notes page sets its cards out in a grid, which a card drawn
/// elsewhere goes by to look as it will there: the notes page's tour, and the
/// settings' preview of the title size.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../widgets/page_gutters.dart';

/// The gap between cards.
const noteCardGap = 14.0;

/// How wide a card grows before another column of them fits.
const noteCardMaxWidth = 220.0;

/// A card's width over its height.
const noteCardAspectRatio = 0.8;

/// How wide the grid grows between the page's margins, at most.
const noteGridMaxWidth = 1040.0;

/// How big each card is in the grid on this screen, so that a card drawn
/// elsewhere, like the settings' preview of the title size, is as big and
/// breaks its title over lines just as it will in the grid.
Size noteCardSize(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final EdgeInsets(:left, :right) = pageGutters(
    context,
    maxWidth: noteGridMaxWidth,
  );
  final gridWidth = width - left - right;
  // As the grid's delegate shares the width out between its columns.
  final columns = math.max(
    1,
    (gridWidth / (noteCardMaxWidth + noteCardGap)).ceil(),
  );
  final cardWidth =
      math.max(0.0, gridWidth - noteCardGap * (columns - 1)) / columns;
  return Size(cardWidth, cardWidth / noteCardAspectRatio);
}
