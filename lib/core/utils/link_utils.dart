class LinkUtils {
  /// Says what it is from the start, as "https://" or "mailto:" does.
  static final _scheme = RegExp(r'^[a-z][a-z\d+.-]*://', caseSensitive: false);
  static final _schemeOnly =
      RegExp(r'^(mailto|tel|sms|geo):', caseSensitive: false);
  static final _email = RegExp(r'^[^\s@/:]+@[^\s@/:]+\.[^\s@/:]+$');

  /// The link [typed] means, so it opens when it's tapped: as it was typed
  /// when it says what it is, an email address to write to, or a web page
  /// otherwise, as "example.com" is. Null when nothing was typed.
  static String? linkOf(String typed) {
    final link = typed.trim();
    if (link.isEmpty) return null;
    if (_scheme.hasMatch(link) || _schemeOnly.hasMatch(link)) return link;
    if (_email.hasMatch(link)) return "mailto:$link";
    return "https://$link";
  }
}
