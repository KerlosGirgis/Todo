import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/view/widgets/page_gutters.dart';

void main() {
  /// A page's margins for at most [maxWidth] on a screen [size] wide, with
  /// [padding] for a camera cutout.
  Future<EdgeInsets> gutters(
    WidgetTester tester,
    Size size, {
    EdgeInsets padding = EdgeInsets.zero,
    double maxWidth = 640,
  }) async {
    late EdgeInsets found;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, padding: padding),
        child: Builder(
          builder: (context) {
            found = pageGutters(context, maxWidth: maxWidth);
            return const SizedBox();
          },
        ),
      ),
    );
    return found;
  }

  testWidgets("a phone's are 16 either side", (tester) async {
    expect(
      await gutters(tester, const Size(412, 915)),
      const EdgeInsets.symmetric(horizontal: 16),
    );
  });

  testWidgets("they clear a camera cutout by 16, on its side only", (
    tester,
  ) async {
    // Turned on its side, a little wider than the most the page shows.
    final found = await gutters(
      tester,
      const Size(700, 412),
      padding: const EdgeInsets.only(left: 48),
    );
    expect(found.left, 64);
    expect(found.right, 30);
  });

  testWidgets("a large screen's centre what's between them, no wider than "
      "the most the page shows", (tester) async {
    final found = await gutters(tester, const Size(1200, 800), maxWidth: 720);
    expect(found, const EdgeInsets.symmetric(horizontal: 240));
    expect(1200 - found.horizontal, 720);
  });
}
