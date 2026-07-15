import 'package:supabase_flutter/supabase_flutter.dart';

class StatisticsService {
  final SupabaseClient client;
  StatisticsService(this.client);

  Future<Map<String, dynamic>> dailySummary(DateTime date) async {
    final value = await client.rpc(
      'get_daily_summary',
      params: {'p_date': _date(date)},
    );
    if (value is! List || value.isEmpty || value.first is! Map)
      throw const FormatException('Invalid daily summary response');
    return Map<String, dynamic>.from(value.first as Map);
  }

  Future<Map<String, dynamic>> weeklySummary(DateTime startDate) async {
    final value = await client.rpc(
      'get_weekly_summary',
      params: {'p_start_date': _date(startDate)},
    );
    if (value is! List || value.isEmpty || value.first is! Map)
      throw const FormatException('Invalid weekly summary response');
    return Map<String, dynamic>.from(value.first as Map);
  }

  static String _date(DateTime value) =>
      value.toIso8601String().substring(0, 10);
}
