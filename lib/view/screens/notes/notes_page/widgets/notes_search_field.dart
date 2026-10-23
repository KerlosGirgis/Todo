import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';

const _accent = Color(0xff3D5AFE);

/// A search field for the notes in the style of iOS's search bars, on the
/// same fill as the to-do page's segmented control. A tap anywhere else puts
/// the keyboard away.
class NotesSearchField extends StatelessWidget {
  const NotesSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final style = TextStyle(color: ink, fontSize: 17, letterSpacing: -0.2);
    return TapRegion(
      onTapOutside: (_) => focusNode.unfocus(),
      child: CupertinoSearchTextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: (_) => focusNode.unfocus(),
        placeholder: "Search",
        style: style,
        placeholderStyle: style.copyWith(color: ink.withValues(alpha: 0.4)),
        itemColor: ink.withValues(alpha: 0.45),
        prefixIcon: const Icon(Icons.search_rounded),
        prefixInsets: const EdgeInsetsDirectional.only(start: 10),
        suffixIcon: const Icon(Icons.cancel_rounded),
        suffixInsets: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 8, 10),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        cursorColor: _accent,
      ),
    );
  }
}
