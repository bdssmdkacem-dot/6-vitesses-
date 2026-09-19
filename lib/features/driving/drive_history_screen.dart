import 'package:flutter/material.dart';
import 'drive_history.dart';
import 'drive_record.dart';

class DriveHistoryScreen extends StatelessWidget {
  const DriveHistoryScreen({super.key, required this.history});
  final DriveHistory history;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: history,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Drive history'),
          actions: [
            if (history.records.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => history.clear(),
              ),
          ],
        ),
        body: history.records.isEmpty
            ? const Center(child: Text('No drives saved yet.'))
            : ListView.builder(
                itemCount: history.records.length,
                itemBuilder: (context, index) {
                  final record = history.records[index];
                  return ListTile(
                    leading: const Icon(Icons.route),
                    title: Text('${record.distanceKm.toStringAsFixed(1)} km'),
                    subtitle: Text('${record.durationSeconds}s • max ${record.maxSpeedKmh.toStringAsFixed(0)} km/h'),
                    onTap: () => _showDetails(context, record),
                  );
                },
              ),
      ),
    );
  }

  void _showDetails(BuildContext context, DriveRecord record) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Drive details'),
        content: Text(
          'Distance: ${record.distanceKm.toStringAsFixed(2)} km\n'
          'Duration: ${record.durationSeconds}s\n'
          'Average: ${record.averageSpeedKmh.toStringAsFixed(1)} km/h\n'
          'Maximum: ${record.maxSpeedKmh.toStringAsFixed(1)} km/h\n'
          'Acceleration: ${record.maxAcceleration.toStringAsFixed(1)} m/s²\n'
          'Braking: ${record.maxBraking.toStringAsFixed(1)} m/s²\n'
          'Lateral G: ${record.maxLateralG.toStringAsFixed(2)} G\n'
          '0–60: ${record.zeroToSixtySeconds?.toStringAsFixed(2) ?? '—'} s\n'
          '0–100: ${record.zeroToHundredSeconds?.toStringAsFixed(2) ?? '—'} s',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}
