import 'package:hive/hive.dart';

import '../models/meeting_model.dart';

abstract class MeetingsLocalDataSource {
  Future<void> cacheMeetings(List<MeetingModel> meetings);
  Future<List<MeetingModel>> getCachedMeetings();
}

class MeetingsLocalDataSourceImpl implements MeetingsLocalDataSource {
  static const String _boxName = 'meetings_box';
  static const String _cacheKey = 'meetings_cache';

  @override
  Future<void> cacheMeetings(List<MeetingModel> meetings) async {
    final box = await Hive.openBox(_boxName);
    final serialized = meetings.map((e) => e.toJson()).toList();
    await box.put(_cacheKey, serialized);
  }

  @override
  Future<List<MeetingModel>> getCachedMeetings() async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(_cacheKey, defaultValue: <dynamic>[]) as List<dynamic>;
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(MeetingModel.fromJson)
        .toList();
  }
}
