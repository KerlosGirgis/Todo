import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/utils/link_utils.dart';
import '../../../profile/profile_page/widgets/profile_button.dart';
import '../../../tasks/todo_page/widgets/form_dialog.dart';

const _accent = Color(0xff3D5AFE);

/// What the link dialog says to do with the link.
sealed class LinkChange {
  const LinkChange();
}

/// The text is to link to [url], and to say [text].
class SetLink extends LinkChange {
  const SetLink({required this.url, required this.text});

  final String url;
  final String text;
}

/// The text is to be plain again.
class RemoveLink extends LinkChange {
  const RemoveLink();
}

/// Links text to a web page, an email address or a phone number, or changes
/// where a link goes: where to, then the text that shows it, which is the
/// link itself if it's left empty. A link being changed can be taken off
/// instead.
class LinkDialog extends StatefulWidget {
  const LinkDialog({
    super.key,
    this.url,
    required this.text,
    this.textEditable = true,
  });

  /// Where the link goes, or null for a new one.
  final String? url;

  /// The text the link is on, or is to be on.
  final String text;

  /// Whether the text can be changed here, which it can't when it runs over
  /// more than one line.
  final bool textEditable;

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  late final _url = TextEditingController(text: widget.url);
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final url = LinkUtils.linkOf(_url.text);
    if (url == null) return;
    final text = _text.text.trim().isEmpty ? _url.text.trim() : _text.text;
    Navigator.of(context)
        .pop(SetLink(url: url, text: widget.textEditable ? text : widget.text));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.url != null;
    final style = TextStyle(
      color: context.colors.wB,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.2,
    );
    return FormDialog(
      icon: Icons.link_rounded,
      title: editing ? "Edit Link" : "Add Link",
      subtitle: editing
          ? "Change where it goes, or take it off."
          : "Where should the text take you?",
      content: [
        TextField(
          controller: _url,
          autofocus: true,
          maxLines: 1,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction:
              widget.textEditable ? TextInputAction.next : TextInputAction.done,
          onSubmitted: widget.textEditable ? null : (_) => _save(),
          cursorColor: _accent,
          style: style,
          decoration: formFieldDecoration(context, hint: "Link"),
        ),
        if (widget.textEditable) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLines: 1,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            cursorColor: _accent,
            style: style,
            decoration: formFieldDecoration(context, hint: "Text"),
          ),
        ],
      ],
      actions: [
        editing
            ? ProfileButton(
                label: "Remove",
                tinted: true,
                onPressed: () => Navigator.of(context).pop(const RemoveLink()),
              )
            : ProfileButton(
                label: "Cancel",
                tinted: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
        // Only once there's somewhere for it to go.
        ListenableBuilder(
          listenable: _url,
          builder: (context, child) => ProfileButton(
            label: editing ? "Save" : "Add",
            onPressed: _url.text.trim().isEmpty ? null : _save,
          ),
        ),
      ],
    );
  }
}
