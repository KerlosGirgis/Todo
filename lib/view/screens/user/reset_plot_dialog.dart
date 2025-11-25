import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../../widgets/button.dart';

class ResetPlotDialog extends StatelessWidget {
  const ResetPlotDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(builder: (context, user, child) {
      return StatefulBuilder(builder: (context,setState) {
        return AlertDialog(
          scrollable: true,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(25),
          ),
          backgroundColor: user.colorManager
              .pageBackground,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height/10,
                child: AutoSizeText(
                  minFontSize: 4,
                  "Are you sure you want to reset?",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                      FontWeight.w600,
                      color: user.colorManager
                          .wB
                  ),
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            Row(
              spacing: MediaQuery.sizeOf(context).width/25,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Button(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    label: 'Cancel',
                    status: false,
                    fontSize: 22,
                    size: 1,
                  ),
                ),
                Expanded(
                  child: Button(
                    onPressed: () {
                      Navigator.pop(context);
                      user.resetPlot();
                    },
                    label: 'Reset',
                    status: true,
                    fontSize: 22,
                    size: 1,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      );
    },

    );
  }
}