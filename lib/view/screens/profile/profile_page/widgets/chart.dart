import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/tasks_view_model.dart';

import '../../../../../core/extensions/theme_extensions.dart';

class Chart extends StatefulWidget {
  const Chart({super.key});

  @override
  State<Chart> createState() => _ChartState();
}

class _ChartState extends State<Chart> {

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TasksViewModel>(context, listen: false).get();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksViewModel>(builder: (context, tasks, child) {
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
                  tasks.finishedTasksCount + tasks.unfinishedTasksCount == 0
                      ? PieChartData(
                    startDegreeOffset: 15,
                    sectionsSpace: 0,
                    centerSpaceRadius: centerRadius,
                    centerSpaceColor: Colors.transparent,
                    sections: [
                      PieChartSectionData(
                        color: context.colors.wB.withValues(alpha: 0.4),
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
                        value: tasks.finishedTasksCount.toDouble(),
                        title:
                        "${((tasks.finishedTasksCount / (tasks.finishedTasksCount + tasks.unfinishedTasksCount)) * 100).ceil()}%",
                        radius: finishedRadius,
                        titleStyle: TextStyle(
                          fontSize: size * 0.08,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: context.colors.wB.withValues(alpha: 0.4),
                        value: tasks.unfinishedTasksCount.toDouble(),
                        title:
                        "${((tasks.unfinishedTasksCount / (tasks.finishedTasksCount + tasks.unfinishedTasksCount)) * 100).floor()}%",
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
                  "Tasks\n${tasks.finishedTasksCount + tasks.unfinishedTasksCount}",
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
      );
    });
  }
}

