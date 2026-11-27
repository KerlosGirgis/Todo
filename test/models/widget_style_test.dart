import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/models/text_size.dart';
import 'package:todo/models/widget_style.dart';

void main() {
  group('as it first comes', () {
    test(
      'the to-do widget is on the phone\'s background, with what\'s left',
      () {
        const style = WidgetStyle.tasksDefault;
        expect(style.background, isNull);
        expect(style.opacity, 1);
        expect(style.textColor, isNull);
        expect(style.accent, 0xff3D5AFE);
        expect(style.textSize, 1);
        expect(style.font, WidgetFont.regular);
        expect(style.showDone, isFalse);
        expect(WidgetStyle.defaultFor(WidgetKind.tasks), style);
      },
    );

    test('the note widget has no background, as it never had', () {
      expect(WidgetStyle.noteDefault.opacity, 0);
      expect(WidgetStyle.defaultFor(WidgetKind.note), WidgetStyle.noteDefault);
    });
  });

  group('kept as JSON', () {
    test('as the phone\'s widgets read it', () {
      const style = WidgetStyle(
        background: 0xff1e1e1e,
        opacity: 0.85,
        textColor: null,
        accent: 0xffFF9500,
        textSize: 1.25,
        font: WidgetFont.casual,
        showDone: true,
      );
      expect(style.toJson(), {
        'background': 0xff1e1e1e,
        'opacity': 0.85,
        'textColor': null,
        'accent': 0xffFF9500,
        'textSize': 1.25,
        'font': 'casual',
        'showDone': true,
      });
      expect(WidgetStyle.fromJson(style.toJson()), style);
    });

    test('with what it lacks as the kind of widget first comes', () {
      final note = WidgetStyle.fromJson({
        'textSize': 1.5,
      }, defaults: WidgetStyle.noteDefault);
      expect(note, WidgetStyle.noteDefault.copyWith(textSize: 1.5));
      expect(WidgetStyle.fromJson({}), WidgetStyle.tasksDefault);
    });

    test('null colours are automatic, and signed ones are read as ARGB', () {
      final style = WidgetStyle.fromJson({
        'background': -16777216, // 0xff000000, as a signed 32-bit number
        'textColor': null,
        'accent': null,
      }, defaults: const WidgetStyle(textColor: 0xffffffff));
      expect(style.background, 0xff000000);
      expect(style.textColor, isNull);
      expect(style.accent, WidgetStyle.defaultAccent);
    });

    test('out of range, or of the wrong kind, as far as it can be', () {
      final style = WidgetStyle.fromJson({
        'opacity': 3,
        'textSize': 0.1,
        'font': 'gothic',
        'showDone': 'yes',
      });
      expect(style.opacity, 1);
      expect(style.textSize, TextSizes.min);
      expect(style.font, WidgetFont.regular);
      expect(style.showDone, isFalse);
    });
  });

  test('copyWith takes null for automatic, and keeps what isn\'t given', () {
    const style = WidgetStyle(background: 0xff000000, textColor: 0xffffffff);
    expect(style.copyWith(opacity: 0.5).background, 0xff000000);
    expect(style.copyWith(background: null).background, isNull);
    expect(style.copyWith(textColor: null).textColor, isNull);
    expect(style.copyWith(textColor: null).background, 0xff000000);
  });

  test('the note widget\'s style from before keeps its size and font', () {
    expect(
      WidgetStyle.legacyNote(textSize: "1.50", casualFont: true),
      const WidgetStyle(opacity: 0, textSize: 1.5, font: WidgetFont.casual),
    );
    expect(WidgetStyle.legacyNote(), WidgetStyle.noteDefault);
    expect(WidgetStyle.legacyNote(textSize: "big").textSize, 1);
    expect(WidgetStyle.legacyNote(textSize: "9").textSize, TextSizes.max);
  });

  group('the text colour', () {
    test('is its own when it has one', () {
      const style = WidgetStyle(textColor: 0xffFF3B30, background: 0xffffffff);
      expect(style.ink, 0xffFF3B30);
    });

    test('stands out against a background of its own that shows', () {
      expect(
        const WidgetStyle(background: 0xffffffff).ink,
        WidgetStyle.darkInk,
      );
      expect(
        const WidgetStyle(background: 0xffFFCC00).ink,
        WidgetStyle.darkInk,
      );
      expect(
        const WidgetStyle(background: 0xff1e1e1e).ink,
        WidgetStyle.lightInk,
      );
      expect(
        const WidgetStyle(background: 0xff3D5AFE).ink,
        WidgetStyle.lightInk,
      );
    });

    test('is the phone\'s on its background, or where little shows', () {
      expect(const WidgetStyle().ink, isNull);
      expect(
        const WidgetStyle(background: 0xffffffff, opacity: 0.45).ink,
        isNull,
      );
      expect(
        const WidgetStyle(background: 0xffffffff, opacity: 0.5).ink,
        WidgetStyle.darkInk,
      );
    });

    test('goes by the same measure as Flutter\'s', () {
      for (var color = 0; color <= 0xffffff; color += 0x0f0f0f ~/ 3 + 7) {
        final argb = 0xff000000 | color;
        expect(
          WidgetStyle.isLight(argb),
          ThemeData.estimateBrightnessForColor(Color(argb)) == Brightness.light,
          reason: argb.toRadixString(16),
        );
      }
    });
  });
}
