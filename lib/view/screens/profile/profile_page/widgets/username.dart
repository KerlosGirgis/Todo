import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../view_model/user_view_model.dart';
import 'edit_name_dialog.dart';

/// The user's name, which opens the dialog that edits it.
class UserName extends StatelessWidget {
  const UserName({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        context.select<UserViewModel, String>((user) => user.user.name);
    return Semantics(
      button: true,
      label: name,
      hint: "Edit name",
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showEditNameDialog(context),
        // Still opens on a long press, as it used to.
        onLongPress: () => showEditNameDialog(context),
        borderRadius: BorderRadius.circular(14),
        splashFactory: NoSplash.splashFactory,
        highlightColor: context.colors.wB.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // As wide as the pencil and its gap, so the name stays centred.
              const SizedBox(width: 24),
              Flexible(
                // Shrinks a long name to fit, rather than cutting it short.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    maxLines: 1,
                    style: TextStyle(
                      color: context.colors.wB,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.edit_rounded,
                size: 18,
                color: context.colors.wB.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
