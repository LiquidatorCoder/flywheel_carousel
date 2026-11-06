import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

const testItems = ['A', 'B', 'C', 'D', 'E'];

/// A phone-width surface so the neighbour cards poke out from behind the
/// centre card.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget carouselApp({
  List<String> items = testItems,
  FlywheelCarouselController? controller,
  ValueChanged<int>? onItemTap,
  ValueChanged<int>? onIndexChanged,
  bool selectOnTap = true,
  bool loop = true,
  int initialIndex = 0,
  String? semanticLabel,
  bool disableAnimations = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: FlywheelCarousel<String>(
            items: items,
            controller: controller,
            onItemTap: onItemTap,
            onIndexChanged: onIndexChanged,
            selectOnTap: selectOnTap,
            loop: loop,
            initialIndex: initialIndex,
            semanticLabel: semanticLabel,
            itemBuilder: (context, item, selected) =>
                Center(child: Text(item, textDirection: TextDirection.ltr)),
          ),
        ),
      ),
    ),
  );
}

PageController pageControllerOf(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!;

/// Centre of the carousel on screen; cards ride below it by up to the arc sag.
Offset carouselTopLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(FlywheelCarousel<String>));

/// A point on the right-hand neighbour card that the centre card does not
/// cover (in carousel coordinates: right of the centre card's edge, on the
/// neighbour's body).
Offset rightNeighbourPoint(WidgetTester tester) {
  final box = tester.getSize(find.byType(FlywheelCarousel<String>));
  final origin = carouselTopLeft(tester);
  return origin + Offset(box.width / 2 + 0.65 * box.width / 2 + 40, 100);
}
