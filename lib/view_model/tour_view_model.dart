import 'package:todo/services/tour_service.dart';

/// The pages the app shows the user around, each with the version of its
/// tour: raising one shows that tour again, to everyone, after an update that
/// changes how its page works.
enum PageTour {
  tasks(1),
  notes(1);

  const PageTour(this.version);

  final int version;
}

/// Which pages' tours are still to be shown. Each shows the first time its
/// page opens, to new users and to those updating from a version before it
/// alike, until they finish it or skip it.
class TourViewModel {
  TourViewModel({TourService? service}) : _service = service ?? TourService();

  final TourService _service;

  /// Whether [tour] is still to be shown.
  Future<bool> isDue(PageTour tour) async {
    try {
      return await _service.seenVersion(tour.name) < tour.version;
    } catch (e) {
      // With nowhere to remember it, the tour would show every time.
      return false;
    }
  }

  /// Remembers that the user has been through [tour], or skipped it.
  Future<void> finish(PageTour tour) async {
    try {
      await _service.setSeenVersion(tour.name, tour.version);
    } catch (e) {
      // It shows again the next time its page opens.
    }
  }
}
