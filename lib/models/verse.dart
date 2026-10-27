/// A Bible verse, as the daily verse shows it.
class Verse {
  const Verse({required this.text, this.reference, required this.raw});

  /// [verse] as the verses are kept: `<text> -- <book chapter:verse>`, with
  /// the book in lower case.
  factory Verse.parse(String verse) {
    final separator = verse.lastIndexOf(" -- ");
    if (separator == -1) return Verse(text: verse, raw: verse);
    return Verse(
      text: verse.substring(0, separator),
      reference: _capitalize(verse.substring(separator + 4)),
      raw: verse,
    );
  }

  final String text;

  /// Where it's from, such as "Song of Solomon 2:4", if it says.
  final String? reference;

  /// The verse as it's kept, which copying it copies.
  final String raw;

  /// "song of solomon 2:4" -> "Song of Solomon 2:4"
  static String _capitalize(String reference) => reference
      .split(" ")
      .map((word) => word.isEmpty || word == "of"
          ? word
          : word[0].toUpperCase() + word.substring(1))
      .join(" ");
}
