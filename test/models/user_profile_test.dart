import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/avatar.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/models/verse.dart';

void main() {
  final stored = <String, Object>{
    'name': "Kerlos",
    'pic': "003",
    'theme': 1,
    'autoSave': 1,
    'casual': 0,
    'verse': 1,
    'count': 0,
    'finished': 0,
    'unFinished': 0,
    'notesTextSize': 1.25,
    'startPage': 1,
    'descLines': 2,
    'tasksTitleSize': 1.0,
    'tasksDescSize': 0.875,
    'notesTitleSize': 1.0,
  };

  test('reads the switches as bools', () {
    final user = UserProfile.fromMap(stored);
    expect(user.darkTheme, isTrue);
    expect(user.autoSave, isTrue);
    expect(user.casualFont, isFalse);
    expect(user.showVerse, isTrue);
    expect(user.wordCount, isFalse);
    expect(user.startPage, StartPage.notes);
    expect(user.avatar, const BundledAvatar("003"));
  });

  test('writes the columns back exactly as they were', () {
    expect(UserProfile.fromMap({...stored, 'id': 1}).toMap(), stored);
  });

  test('reads sizes kept as whole numbers', () {
    expect(
        UserProfile.fromMap({...stored, 'notesTextSize': 1}).notesTextSize,
        1.0);
  });

  test('opens on the notes for any start page but the first', () {
    expect(UserProfile.fromMap({...stored, 'startPage': 0}).startPage,
        StartPage.tasks);
    expect(UserProfile.fromMap({...stored, 'startPage': 2}).startPage,
        StartPage.notes);
  });

  group('Avatar', () {
    test('reads a number as a bundled avatar and a path as a photo', () {
      expect(Avatar.decode("007"), const BundledAvatar("007"));
      expect(Avatar.decode("/data/user/0/com.k.todo/app_flutter/me.jpg"),
          const PhotoAvatar("/data/user/0/com.k.todo/app_flutter/me.jpg"));
    });

    test('writes itself back as it was', () {
      expect(Avatar.decode("009").encoded, "009");
      expect(Avatar.decode("/a/b.jpg").encoded, "/a/b.jpg");
    });

    test('shows the plain avatar for a number it has no picture for', () {
      expect(const BundledAvatar("042").asset, "assets/avatars/avatar.png");
      expect(const BundledAvatar("001").asset,
          "assets/avatars/avatar_hacker.png");
    });

    test('offers the ten bundled avatars', () {
      expect(BundledAvatar.all.map((avatar) => avatar.number), [
        for (var i = 0; i < 10; i++) "00$i",
      ]);
    });
  });

  group('Verse', () {
    test('splits off its reference, in title case', () {
      final verse = Verse.parse(
          "Many waters cannot quench love -- song of solomon 8:7");
      expect(verse.text, "Many waters cannot quench love");
      expect(verse.reference, "Song of Solomon 8:7");
      expect(verse.raw,
          "Many waters cannot quench love -- song of solomon 8:7");
    });

    test('is all text without a reference', () {
      final verse = Verse.parse("Jesus wept.");
      expect(verse.text, "Jesus wept.");
      expect(verse.reference, isNull);
    });
  });
}
