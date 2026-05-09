import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/reset_plot_dialog.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../view_model/user_view_model.dart';

class Chart extends StatelessWidget {
  const Chart({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return
      Consumer<UserViewModel>(
          builder: (context, user, child) {
            return GestureDetector(
              child: LayoutBuilder(
                builder: (context, constraints) {
              final size = constraints.biggest.width;
              final centerRadius = size * 0.20;
              final finishedRadius = size * 0.30;
              final unFinishedRadius = size * 0.25;
              final fontSize = size * 0.10;

              return Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    user.user.unFinished == 0 &&
                        user.user.finished == 0
                        ? PieChartData(
                      startDegreeOffset: 15,
                      sectionsSpace: 0,
                      centerSpaceRadius: centerRadius,
                      centerSpaceColor: Colors.transparent,
                      sections: [
                        PieChartSectionData(
                          color: context.colors.wB
                              .withValues(alpha: 0.4),
                          value: 1,
                          title: "",
                          radius: finishedRadius,
                        ),
                      ],
                    )
                        : PieChartData(
                      startDegreeOffset: 15,
                      sectionsSpace: 0,
                      centerSpaceRadius: centerRadius,
                      centerSpaceColor: Colors.transparent,
                      sections: [
                        PieChartSectionData(
                          color: const Color(0xff3D5AFE),
                          value: user.user.finished.toDouble(),
                          title:
                          "${((user.user.finished / (user.user.finished + user.user.unFinished)) * 100).ceil()}%",
                          radius: finishedRadius,
                          titleStyle: TextStyle(
                            fontSize: size * 0.08,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: context.colors.wB
                              .withValues(alpha: 0.4),
                          value: user.user.unFinished.toDouble(),
                          title:
                          "${((user.user.unFinished / (user.user.finished + user.user.unFinished)) * 100).floor()}%",
                          radius: unFinishedRadius,
                          titleStyle: TextStyle(
                            fontSize: size * 0.08,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "Tasks\n${user.user.finished + user.user.unFinished}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: context.colors.wB,
                    ),
                  ),
                ],
              );
            },
            ),
              onLongPress: () {
                showDialog(
                    context: context,
                    builder: (builder) {
                      return ResetPlotDialog();
                    });
              },
            );
          });

  }
}
