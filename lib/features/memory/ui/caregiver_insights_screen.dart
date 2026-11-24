import 'package:flutter/material.dart';

import '../application/memory_support_service.dart';
import '../domain/i_prediction_service.dart';
import '../domain/memory.dart';
import '../memory_module.dart';

/// UI layer – Caregiver Screens subsystem.
///
/// Shows what the ML models have learned about one patient: today's predicted
/// risk by hour, when they are usually upset, and which memories help most.
class CaregiverInsightsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final MemorySupportService? service;

  const CaregiverInsightsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.service,
  });

  @override
  State<CaregiverInsightsScreen> createState() =>
      _CaregiverInsightsScreenState();
}

class _InsightsData {
  final PatientInsights? insights;
  final Map<String, Memory> memories;
  const _InsightsData(this.insights, this.memories);
}

class _CaregiverInsightsScreenState extends State<CaregiverInsightsScreen> {
  late final MemorySupportService service;
  late Future<_InsightsData> _future;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? MemoryModule.service;
    _future = _load();
  }

  Future<_InsightsData> _load() async {
    final memories = await service.getMemoriesForPatient(widget.patientId);
    final insights = await service.getInsights(widget.patientId);
    return _InsightsData(insights, {
      for (final m in memories)
        if (m.memoryId != null) m.memoryId!: m,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Insights: ${widget.patientName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
      body: FutureBuilder<_InsightsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final insights = snapshot.data?.insights;
          if (insights == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Insights need the Memora ML service. Check the internet '
                  'connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            );
          }
          return _content(insights, snapshot.data!.memories);
        },
      ),
    );
  }

  Widget _content(PatientInsights insights, Map<String, Memory> memories) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (insights.summary.isEmpty)
          const Text('Not enough check-ins yet. Insights appear after a few days of moods.')
        else
          ...insights.summary.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.insights, size: 20, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: const TextStyle(fontSize: 16))),
                  ],
                ),
              )),
        const SizedBox(height: 16),
        Text('Predicted risk today', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _hourChart(insights),
        const SizedBox(height: 24),
        Text('Upset check-ins, last 2 weeks', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...insights.upsetByTimeOfDay.map((p) => _shareRow(
            p.period, p.upsetShare, '${p.checkIns} check-ins')),
        const SizedBox(height: 24),
        Text('Memories that help most', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (insights.bestMemories.isEmpty)
          const Text('No memories yet.')
        else
          ...insights.bestMemories.map((r) {
            final memory = memories[r.memoryId];
            final name = memory == null
                ? r.memoryId
                : (memory.personName.isNotEmpty ? memory.personName : memory.title);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
              title: Text(name),
              subtitle: Text(r.reason),
              trailing: Text('${(r.expectedHelp * 100).round()}%',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            );
          }),
        const SizedBox(height: 16),
        const Text(
          'Predictions help plan the day; they are not a diagnosis.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _hourChart(PatientInsights insights) {
    const height = 140.0;
    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: insights.riskByHour.map((h) {
          final peak = h.hour == insights.peakHour;
          return Expanded(
            child: Tooltip(
              message: '${_hourLabel(h.hour)}: ${(h.risk * 100).round()}%',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: h.risk.clamp(0.0, 1.0).toDouble() * height,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: peak ? Colors.deepPurple : Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(h.hour % 3 == 0 ? _hourLabel(h.hour) : '',
                      style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _shareRow(String label, double share, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0).toDouble(),
                minHeight: 14,
                color: Colors.deepPurple,
                backgroundColor: Colors.deepPurple.shade50,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text('${(share * 100).round()}% · $detail',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  static String _hourLabel(int h) =>
      '${h % 12 == 0 ? 12 : h % 12}${h < 12 ? 'am' : 'pm'}';
}
