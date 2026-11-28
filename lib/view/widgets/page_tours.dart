import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../view_model/tour_view_model.dart';
import 'tour.dart';

/// How long a page takes to rise in, which its tour waits for.
const _riseIn = Duration(milliseconds: 900);

/// What the to-do and notes pages share in showing their tours, each once:
/// waiting for the page to rise in, marking it seen as it ends, and hearing
/// when the user asks for the tips again. The page says when a tour is due,
/// in [toursReplayed] and as it opens, what each one shows, in [tourSteps],
/// and shows them in a [Tour] with [tourController].
mixin PageTours<T extends StatefulWidget> on State<T> {
  /// The tour on show, for the page's [Tour].
  final tourController = TourController();

  /// Whether a tour is on, or about to be: the page gives what it points at
  /// their keys then.
  bool touring = false;

  /// Which tours are due, and which have been seen.
  late final TourViewModel tours;

  Timer? _tourStart;

  /// Whether a tour is waiting for the page to rise in.
  bool get tourStarting => _tourStart?.isActive ?? false;

  /// As the user asks for the tips again in the settings.
  void toursReplayed();

  /// The steps of [tour], as the page is when it starts.
  List<TourStep> tourSteps(PageTour tour);

  @override
  void initState() {
    super.initState();
    tours = context.read<TourViewModel>()..addListener(toursReplayed);
  }

  @override
  void dispose() {
    tours.removeListener(toursReplayed);
    _tourStart?.cancel();
    tourController.dispose();
    super.dispose();
  }

  /// Starts [tour] once the page has risen in, unless [stopTourStart] comes
  /// first. The page sets [touring] as it calls this.
  void startTourSoon(PageTour tour) {
    _tourStart?.cancel();
    _tourStart = Timer(_riseIn, () => startTour(tour));
  }

  /// Keeps a tour that's waiting for the page from starting.
  void stopTourStart() => _tourStart?.cancel();

  /// Starts [tour] now. It's seen once it ends.
  void startTour(PageTour tour) {
    tourController.start(
      tourSteps(tour),
      onEnd: () {
        setState(() => touring = false);
        tours.finish(tour);
      },
    );
  }
}
