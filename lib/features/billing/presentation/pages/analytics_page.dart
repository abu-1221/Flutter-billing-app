import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/data/hive_database.dart';

import '../../../../core/widgets/custom_charts.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Analytics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveDatabase.transactionsBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return _buildEmptyState();
          }

          final List transactions = box.values.toList();
          
          // Calculate Metrics
          final now = DateTime.now();
          final todayStr = DateFormat('yyyy-MM-dd').format(now);
          
          double todayRevenue = 0.0;
          double weeklyRevenue = 0.0;
          double monthlyRevenue = 0.0;
          double totalTax = 0.0;
          double totalRevenue = 0.0;
          int totalProductsSold = 0;

          final Map<String, int> productSales = {};

          for (var t in transactions) {
            final trans = t as Map<dynamic, dynamic>;
            final double grandTotal = trans['grandTotal'] as double? ?? 0.0;
            final double tax = trans['tax'] as double? ?? 0.0;
            final String dateStr = trans['date'] ?? '';
            final List items = trans['items'] as List? ?? [];

            totalRevenue += grandTotal;
            totalTax += tax;

            // Product quantity calculations
            for (var item in items) {
              final String name = item['name'] ?? 'Unknown';
              final int qty = item['qty'] as int? ?? 1;
              totalProductsSold += qty;
              productSales[name] = (productSales[name] ?? 0) + qty;
            }

            try {
              final DateTime transDate = DateFormat('yyyy-MM-dd').parse(dateStr);
              final diff = now.difference(transDate).inDays;

              if (dateStr == todayStr) {
                todayRevenue += grandTotal;
              }
              if (diff <= 7) {
                weeklyRevenue += grandTotal;
              }
              if (diff <= 30) {
                monthlyRevenue += grandTotal;
              }
            } catch (e) {
              // Parse error
            }
          }

          final int totalTrans = transactions.length;
          final double avgOrderValue = totalTrans > 0 ? totalRevenue / totalTrans : 0.0;

          // Top products
          final sortedProducts = productSales.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          
          final topProducts = sortedProducts.take(3).toList();

          // Prepare charts data
          // Daily sales charts (last 7 days)
          final List<double> dailyValues = [];
          final List<String> dailyLabels = [];
          for (int i = 6; i >= 0; i--) {
            final day = now.subtract(Duration(days: i));
            final dayStr = DateFormat('yyyy-MM-dd').format(day);
            final labelStr = DateFormat('E').format(day); // e.g. Mon, Tue

            double dayTotal = 0.0;
            for (var t in transactions) {
              final trans = t as Map<dynamic, dynamic>;
              if (trans['date'] == dayStr) {
                dayTotal += trans['grandTotal'] as double? ?? 0.0;
              }
            }
            dailyValues.add(dayTotal);
            dailyLabels.add(labelStr);
          }

          // Pie chart segments for top products
          final List<PieChartSegment> pieSegments = [];
          final colors = [Colors.indigo, Colors.teal, Colors.amber, Colors.red];
          int segmentIndex = 0;
          int topSum = 0;
          for (var p in topProducts) {
            pieSegments.add(PieChartSegment(
              label: p.key,
              value: p.value.toDouble(),
              color: colors[segmentIndex % colors.length],
            ));
            topSum += p.value;
            segmentIndex++;
          }
          final otherQty = totalProductsSold - topSum;
          if (otherQty > 0) {
            pieSegments.add(PieChartSegment(
              label: 'Others',
              value: otherQty.toDouble(),
              color: Colors.grey[400]!,
            ));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Revenue Cards Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Today',
                        value: '₹${todayRevenue.toStringAsFixed(0)}',
                        icon: Icons.today,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Weekly',
                        value: '₹${weeklyRevenue.toStringAsFixed(0)}',
                        icon: Icons.calendar_view_week,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Monthly',
                        value: '₹${monthlyRevenue.toStringAsFixed(0)}',
                        icon: Icons.calendar_month,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'All-Time',
                        value: '₹${totalRevenue.toStringAsFixed(0)}',
                        icon: Icons.show_chart,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Transaction stats
                const Text('Transaction Metrics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow('Total Invoices', '$totalTrans'),
                      const Divider(height: 24),
                      _buildStatRow('Average Invoice Value', '₹${avgOrderValue.toStringAsFixed(2)}'),
                      const Divider(height: 24),
                      _buildStatRow('Total Products Sold', '$totalProductsSold pcs'),
                      const Divider(height: 24),
                      _buildStatRow('Total GST Collected', '₹${totalTax.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Charts Section
                const Text('Daily Revenue (Last 7 Days)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: CustomBarChart(values: dailyValues, labels: dailyLabels),
                ),
                const SizedBox(height: 24),

                const Text('Sales Trend Line',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: CustomLineChart(values: dailyValues, labels: dailyLabels, lineColor: Colors.indigo),
                ),
                const SizedBox(height: 24),

                const Text('Product Share Distribution',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: CustomPieChart(segments: pieSegments),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No sales statistics found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Transactions will compile statistics reactively.', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}
