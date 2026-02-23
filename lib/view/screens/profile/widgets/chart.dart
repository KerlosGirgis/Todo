import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/view/screens/profile/widgets/reset_plot_dialog.dart';

import '../../../../view_model/user_view_model.dart';

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
              child: PieChart(
                user.user.unFinished == 0 &&
                    user.user.finished == 0
                    ? PieChartData(
                  startDegreeOffset: 15,
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                        color: Colors.grey,
                        value: 1,
                        title: " ",
                        radius: 60,
                        titleStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.white,
                            overflow: TextOverflow
                                .ellipsis)),
                  ],
                )
                    : PieChartData(
                  startDegreeOffset: 15,
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                        color: Color(0xff3D5AFE),
                        value: user.user.finished
                            .toDouble(),
                        title:
                        "${((user.user.finished / (user.user.finished + user.user.unFinished)) * 100).ceil()}%",
                        radius: 60,
                        titleStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.white,
                            overflow: TextOverflow
                                .ellipsis)),
                    PieChartSectionData(
                        color: user.colorManager.wB?.withValues(alpha: 0.4),
                        value: user.user.unFinished
                            .toDouble(),
                        title:
                        "${((user.user.unFinished / (user.user.finished + user.user.unFinished)) * 100).floor()}%",
                        radius: 50,
                        titleStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.white,
                            overflow: TextOverflow
                                .ellipsis))
                  ],
                ),
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
