import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/services/tour_service.dart';
import 'package:todo/view_model/tour_view_model.dart';

/// Settings that can't be read or written.
class BrokenTourService extends TourService {
  @override
  Future<int> seenVersion(String tour) => Future.error(StateError("Broken"));

  @override
  Future<void> setSeenVersion(String tour, int version) =>
      Future.error(StateError("Broken"));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('each tour is due until it is finished', () async {
    final tours = TourViewModel();
    expect(await tours.isDue(PageTour.tasks), isTrue);
    expect(await tours.isDue(PageTour.notes), isTrue);

    await tours.finish(PageTour.tasks);
    expect(await tours.isDue(PageTour.tasks), isFalse);
    expect(await tours.isDue(PageTour.notes), isTrue);
  });

  test('a finished tour stays finished the next time the app opens',
      () async {
    await TourViewModel().finish(PageTour.notes);
    expect(await TourViewModel().isDue(PageTour.notes), isFalse);
  });

  test('a tour is due again for those who saw an older version of it',
      () async {
    SharedPreferences.setMockInitialValues(
        {'tour.tasks': PageTour.tasks.version - 1});
    expect(await TourViewModel().isDue(PageTour.tasks), isTrue);
  });

  test('no tour shows without settings to remember it in', () async {
    final tours = TourViewModel(service: BrokenTourService());
    expect(await tours.isDue(PageTour.tasks), isFalse);
    await tours.finish(PageTour.tasks);
  });
}
