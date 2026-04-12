import '../entities/meeting_entity.dart';

class PaginatedMeetings {
  const PaginatedMeetings({
    required this.items,
    required this.hasMore,
  });

  final List<MeetingEntity> items;
  final bool hasMore;
}

abstract class MeetingsRepository {
  Future<PaginatedMeetings> getMeetings({int page = 1, int limit = 20});
  Future<void> syncPendingData();
}
