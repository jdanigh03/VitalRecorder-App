import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  final Color primaryColor;
  final String title;

  const TrendChart({
    Key? key,
    required this.trendData,
    this.primaryColor = const Color(0xFF4A90E2),
    this.title = 'Evolución de Adherencia',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (trendData.isEmpty) {
      return _buildEmptyChart();
    }

    return Card(
      elevation: 2,
      child: Container(
        height: 250,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: trendData.length > 7 ? (trendData.length / 4).ceil().toDouble() : 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value.toInt() >= 0 && value.toInt() < trendData.length) {
                            final date = trendData[value.toInt()]['date'] as DateTime;
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return Container();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 40,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  minX: 0,
                  maxX: trendData.length.toDouble() - 1,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: trendData.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          (entry.value['adherence'] as int).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.3)],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: primaryColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.2),
                            primaryColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: primaryColor.withOpacity(0.9),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final date = trendData[barSpot.x.toInt()]['date'] as DateTime;
                          final adherence = barSpot.y.toInt();
                          final completed = trendData[barSpot.x.toInt()]['completed'];
                          final total = trendData[barSpot.x.toInt()]['total'];
                          
                          return LineTooltipItem(
                            '${DateFormat('dd/MM').format(date)}\nAdherencia: $adherence%\nCompletados: $completed/$total',
                            TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Card(
      elevation: 2,
      child: Container(
        height: 250,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: 12),
            Text(
              'Sin datos para mostrar',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Selecciona un período con datos',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TypeDistributionChart extends StatelessWidget {
  final Map<String, dynamic> distribution;
  final String title;

  const TypeDistributionChart({
    Key? key,
    required this.distribution,
    this.title = 'Distribución por Tipos',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (sum, value) => sum + (value as int));
    
    if (total == 0) {
      return _buildEmptyChart();
    }

    final List<PieChartSectionData> sections = [];
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
    ];

    int colorIndex = 0;
    distribution.forEach((key, value) {
      if (value > 0) {
        final percentage = ((value / total) * 100).round();
        sections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: value.toDouble(),
            title: '$percentage%',
            radius: 60,
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      }
    });

    return Card(
      elevation: 2,
      child: Container(
        height: 300,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            // Handle touch events if needed
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _buildLegend(distribution, colors),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLegend(Map<String, dynamic> distribution, List<Color> colors) {
    final items = <Widget>[];
    int colorIndex = 0;
    
    distribution.forEach((key, value) {
      if (value > 0) {
        final label = _getLabelForKey(key);
        items.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[colorIndex % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        colorIndex++;
      }
    });
    
    return items;
  }

  String _getLabelForKey(String key) {
    switch (key.toLowerCase()) {
      case 'medicacion':
        return 'Medicación';
      case 'actividad':
        return 'Actividad';
      case 'otros':
        return 'Otros';
      default:
        return key;
    }
  }

  Widget _buildEmptyChart() {
    return Card(
      elevation: 2,
      child: Container(
        height: 300,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: 12),
            Text(
              'Sin datos para mostrar',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdherenceBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> patientStats;
  final String title;

  const AdherenceBarChart({
    Key? key,
    required this.patientStats,
    this.title = 'Adherencia por Paciente',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (patientStats.isEmpty) {
      return _buildEmptyChart();
    }

    // Tomar solo los primeros 10 pacientes para el gráfico
    final displayStats = patientStats.take(10).toList();

    return Card(
      elevation: 2,
      child: Container(
        height: 300,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  minY: 0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Color(0xFF4A90E2).withOpacity(0.9),
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final patient = displayStats[groupIndex]['patient'];
                        final adherence = displayStats[groupIndex]['adherencia'];
                        final completed = displayStats[groupIndex]['completados'];
                        final total = displayStats[groupIndex]['totalRecordatorios'];
                        
                        return BarTooltipItem(
                          '${patient.nombreCompleto}\nAdherencia: $adherence%\nCompletados: $completed/$total',
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value.toInt() >= 0 && value.toInt() < displayStats.length) {
                            final patient = displayStats[value.toInt()]['patient'];
                            final name = patient.nombreCompleto;
                            final displayName = name.length > 8 ? name.substring(0, 8) + '...' : name;
                            
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Transform.rotate(
                                angle: -0.5,
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Container();
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 40,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  barGroups: displayStats.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stat = entry.value;
                    final adherence = stat['adherencia'] as int;
                    
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: adherence.toDouble(),
                          color: _getColorForAdherence(adherence),
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 100,
                            color: Colors.grey[200],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForAdherence(int adherence) {
    if (adherence >= 80) return Colors.green;
    if (adherence >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildEmptyChart() {
    return Card(
      elevation: 2,
      child: Container(
        height: 300,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: 12),
            Text(
              'Sin datos para mostrar',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}