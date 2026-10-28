import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/utils/link_utils.dart';

void main() {
  test('a web address on its own is a web page', () {
    expect(LinkUtils.linkOf("example.com"), "https://example.com");
    expect(LinkUtils.linkOf("example.com:8080/a?b=c"),
        "https://example.com:8080/a?b=c");
  });

  test('a link that says what it is stays as it was typed', () {
    expect(LinkUtils.linkOf("http://example.com"), "http://example.com");
    expect(LinkUtils.linkOf("HTTPS://Example.com"), "HTTPS://Example.com");
    expect(LinkUtils.linkOf("mailto:me@example.com"), "mailto:me@example.com");
    expect(LinkUtils.linkOf("tel:+15551234"), "tel:+15551234");
  });

  test('an email address is written to', () {
    expect(LinkUtils.linkOf("me@example.com"), "mailto:me@example.com");
  });

  test('leaves out the spaces around it, and nothing is no link', () {
    expect(LinkUtils.linkOf("  example.com \n"), "https://example.com");
    expect(LinkUtils.linkOf("   "), isNull);
  });
}
