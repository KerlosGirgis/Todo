import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/note.dart';

void main() {
  Note withColors(Object? title, Object? cover) =>
      Note.fromMap({'title': "t", 'titleColor': title, 'coverColor': cover});

  test('reads colours as the colour picker wrote them', () {
    final note = withColors("FF3B30", "#1E1E1E");
    expect(note.titleColor, 0xFFFF3B30);
    expect(note.coverColor, 0xFF1E1E1E);
  });

  test('reads colours with their alpha, or in the short form', () {
    expect(withColors("80FF3B30", "fff").titleColor, 0x80FF3B30);
    expect(withColors("80FF3B30", "fff").coverColor, 0xFFFFFFFF);
  });

  test('reads colours from before they were strings', () {
    expect(withColors(0xFF5856D6, 0xFF000000).titleColor, 0xFF5856D6);
  });

  test('takes a white title on graphite when a note has no colours', () {
    final note = withColors(null, null);
    expect(note.titleColor, Note.defaultTitleColor);
    expect(note.coverColor, Note.defaultCoverColor);
  });

  test('takes black for a colour it cannot read, as the picker does', () {
    expect(withColors("", "zz").titleColor, 0xFF000000);
    expect(withColors("", "zz").coverColor, 0xFF000000);
  });

  test('writes colours as "RRGGBB"', () {
    final map = const Note(
      title: "t",
      titleColor: 0xFFFFFFFF,
      coverColor: 0xFF00C7BE,
    ).toMap();
    expect(map['titleColor'], "FFFFFF");
    expect(map['coverColor'], "00C7BE");
  });

  test('keeps its lock as protected 1 or 0', () {
    final locked = Note.fromMap({'title': "t", 'protected': 1});
    expect(locked.locked, isTrue);
    expect(locked.toMap()['protected'], 1);
    expect(Note.fromMap({'title': "t"}).locked, isFalse);
  });

  test('round-trips a stored note', () {
    final stored = {
      'title': "t",
      'body': "b",
      'delta': '[{"insert":"b\\n"}]',
      'titleColor': "FFFFFF",
      'coverColor': "5856D6",
      'protected': 1,
    };
    expect(Note.fromMap(stored).toMap(), stored);
  });

  test('without its text, a note keeps all but its text', () {
    const note = Note(
      id: 3,
      title: "t",
      body: "secret",
      delta: "[]",
      coverColor: 0xFF5856D6,
      locked: true,
    );
    final shown = note.withoutText();
    expect(shown.body, "");
    expect(shown.delta, isNull);
    expect(shown.id, 3);
    expect(shown.title, "t");
    expect(shown.coverColor, 0xFF5856D6);
    expect(shown.locked, isTrue);
  });
}
