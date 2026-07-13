import 'package:flutter/material.dart';

import '../../models/water_intake_record.dart';
import '../../repositories/water_tracking_repository.dart';
import 'add_water_sheet.dart';

Future<void> showWaterTrackingPage({
  required BuildContext context,
  required String date,
  required WaterTrackingRepository repository,
  required ValueChanged<int> onTotalChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF4F5F7),
    builder: (_) => WaterTrackingPage(
      date: date,
      repository: repository,
      onTotalChanged: onTotalChanged,
    ),
  );
}

class WaterTrackingPage extends StatefulWidget {
  final String date;
  final WaterTrackingRepository repository;
  final ValueChanged<int> onTotalChanged;

  const WaterTrackingPage({
    super.key,
    required this.date,
    required this.repository,
    required this.onTotalChanged,
  });

  @override
  State<WaterTrackingPage> createState() => _WaterTrackingPageState();
}

class _WaterTrackingPageState extends State<WaterTrackingPage> {
  late List<WaterIntakeRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = widget.repository.waterRecordsForDate(widget.date);
  }

  int get _total => _records.fold(0, (sum, record) => sum + record.amountMl);

  Future<void> _add({WaterIntakeRecord? record}) async {
    final draft = await showAddWaterSheet(
      context: context,
      date: widget.date,
      initialRecord: record,
    );
    if (draft == null || !mounted) return;
    final updated = WaterIntakeRecord(
      id: record?.id ?? 'water_${DateTime.now().microsecondsSinceEpoch}',
      date: widget.date,
      recordedAt: draft.recordedAt,
      amountMl: draft.amountMl,
    );
    if (record == null) {
      await widget.repository.addWaterRecord(updated);
    } else {
      await widget.repository.updateWaterRecord(updated);
    }
    if (!mounted) return;
    setState(() {
      final index = _records.indexWhere((item) => item.id == updated.id);
      if (index == -1) {
        _records.add(updated);
      } else {
        _records[index] = updated;
      }
      _records.sort((a, b) {
        final aTime = a.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    });
    widget.onTotalChanged(_total);
  }

  Future<void> _delete(WaterIntakeRecord record) async {
    await widget.repository.deleteWaterRecord(record.id);
    if (!mounted) return;
    setState(() => _records.removeWhere((item) => item.id == record.id));
    widget.onTotalChanged(_total);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '今日饮水',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$_total ml',
                    style: const TextStyle(
                      color: Color(0xFF008C8C),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('记录饮水'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C8C),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _records.isEmpty
                    ? const Center(child: Text('今天还没有饮水记录'))
                    : ListView.separated(
                        itemCount: _records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final record = _records[index];
                          final time =
                              record.isLegacyAggregate ||
                                  record.recordedAt == null
                              ? '历史汇总'
                              : '${record.recordedAt!.hour.toString().padLeft(2, '0')}:${record.recordedAt!.minute.toString().padLeft(2, '0')}';
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                title: Text(time),
                                subtitle: null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${record.amountMl} ml',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '编辑饮水',
                                      onPressed: () => _add(record: record),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: '删除饮水',
                                      onPressed: () => _delete(record),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
