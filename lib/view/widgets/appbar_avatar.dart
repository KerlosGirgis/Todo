import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/ui/feedback_toast.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../../core/extensions/theme_extensions.dart';
import 'ringed_avatar.dart';

const _accent = Color(0xff3D5AFE);

class AppbarAvatar extends StatefulWidget {
  const AppbarAvatar({
    super.key,
  });

  @override
  State<AppbarAvatar> createState() => _AppbarAvatarState();
}

class _AppbarAvatarState extends State<AppbarAvatar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // One tag per page, so the avatar flies into its own dialog but not
    // between the Todo and Notes pages when one replaces the other.
    final heroTag = (AppbarAvatar, ModalRoute.of(context));
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        return Semantics(
          button: true,
          label: "Profile",
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              onTap: () {
                // A PageRoute rather than showGeneralDialog, because heroes
                // only fly between PageRoutes.
                Navigator.of(context, rootNavigator: true).push(
                  PageRouteBuilder(
                    opaque: false,
                    barrierDismissible: true,
                    barrierColor: Colors.black54,
                    barrierLabel: MaterialLocalizations.of(context)
                        .modalBarrierDismissLabel,
                    transitionDuration: const Duration(milliseconds: 350),
                    reverseTransitionDuration:
                        const Duration(milliseconds: 300),
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        _ProfileDialog(
                      heroTag: heroTag,
                      pic: user.user.pic,
                      name: user.user.name,
                      verse: user.dailyVerse,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      var curvedAnimation = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic);
                      return FadeTransition(
                        opacity: curvedAnimation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1)
                              .animate(curvedAnimation),
                          child: child,
                        ),
                      );
                    },
                  ),
                );
              },
              child: SizedBox.square(
                dimension: 44,
                child:
                    Hero(tag: heroTag, child: RingedAvatar(pic: user.user.pic)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileDialog extends StatelessWidget {
  const _ProfileDialog({
    required this.heroTag,
    required this.pic,
    required this.name,
    required this.verse,
  });

  final Object heroTag;
  final String pic;
  final String name;

  /// Today's verse, or null when the daily verse is turned off.
  final String? verse;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox.square(
                dimension: 152,
                child: AvatarHalo(
                  child: Hero(tag: heroTag, child: RingedAvatar(pic: pic)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.wB,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (verse != null) ...[
              const SizedBox(height: 24),
              _VerseCard(verse: verse!),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.verse});

  final String verse;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final accent = context.colors.moreLess;
    // Verses are stored as "<text> -- <book chapter:verse>".
    final separator = verse.lastIndexOf(" -- ");
    final text = separator == -1 ? verse : verse.substring(0, separator);
    final reference = separator == -1
        ? null
        : _formatReference(verse.substring(separator + 4));

    void copy() {
      Clipboard.setData(ClipboardData(text: verse)).then((_) {
        FeedbackToast.info("Verse copied to clipboard");
      });
    }

    return Material(
      color: _accent.withValues(alpha: isDarkTheme ? 0.14 : 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onLongPress: copy,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 4, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text("🕯️", style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "BIBLE VERSE",
                      style: TextStyle(
                        color: accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: copy,
                    tooltip: "Copy verse",
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: context.colors.wB.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  text,
                  style: TextStyle(
                    color: context.colors.wB.withValues(alpha: 0.9),
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
              if (reference != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 14),
                  child: Text(
                    "— $reference",
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "song of solomon 2:4" -> "Song of Solomon 2:4"
String _formatReference(String reference) => reference
    .split(" ")
    .map((word) => word.isEmpty || word == "of"
        ? word
        : word[0].toUpperCase() + word.substring(1))
    .join(" ");
