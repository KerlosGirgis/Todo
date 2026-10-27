/// The user's picture: one of the avatars that come with the app, or a
/// photo of their own.
sealed class Avatar {
  const Avatar();

  /// [pic] as the profile keeps it: a bundled avatar's number, such as
  /// "000", or the path of a photo the user picked.
  factory Avatar.decode(String pic) =>
      pic.startsWith("0") ? BundledAvatar(pic) : PhotoAvatar(pic);

  /// The avatar as the profile keeps it.
  String get encoded;
}

/// One of the avatars that come with the app, by its number.
final class BundledAvatar extends Avatar {
  const BundledAvatar(this.number);

  static const fallback = BundledAvatar("000");

  /// Every avatar that comes with the app, in the order they're offered.
  static const all = [
    fallback,
    BundledAvatar("001"),
    BundledAvatar("002"),
    BundledAvatar("003"),
    BundledAvatar("004"),
    BundledAvatar("005"),
    BundledAvatar("006"),
    BundledAvatar("007"),
    BundledAvatar("008"),
    BundledAvatar("009"),
  ];

  final String number;

  /// The picture's asset, or the plain avatar's for a number there's no
  /// picture for.
  String get asset => switch (number) {
        "001" => "assets/avatars/avatar_hacker.png",
        "002" => "assets/avatars/avatar_man_1.png",
        "003" => "assets/avatars/avatar_man_2.png",
        "004" => "assets/avatars/avatar_man_3.png",
        "005" => "assets/avatars/avatar_man_4.png",
        "006" => "assets/avatars/avatar_woman_1.png",
        "007" => "assets/avatars/avatar_woman_2.png",
        "008" => "assets/avatars/avatar_woman_3.png",
        "009" => "assets/avatars/avatar_woman_4.png",
        _ => "assets/avatars/avatar.png",
      };

  @override
  String get encoded => number;

  @override
  bool operator ==(Object other) =>
      other is BundledAvatar && other.number == number;

  @override
  int get hashCode => number.hashCode;
}

/// A photo the user picked, kept in the app's own storage.
final class PhotoAvatar extends Avatar {
  const PhotoAvatar(this.path);

  final String path;

  @override
  String get encoded => path;

  @override
  bool operator ==(Object other) => other is PhotoAvatar && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
