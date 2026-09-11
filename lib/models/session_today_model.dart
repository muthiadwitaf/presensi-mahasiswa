class SessionToday {
  final DateTime? sessionDate;
  final String sessionSource;
  final String? meetingSessionId;
  final String courseClassId;
  final String courseCode;
  final String courseName;
  final String? lecturerName;
  final String startTime;
  final String endTime;
  final String mode;
  final String? locationName;
  final String? meetingUrl;
  final String sessionStatus;

  final String? attendanceId;
  final String? attendanceStatus;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final int? minutesLate;
  final double? checkInLatitude;
  final double? checkInLongitude;

  const SessionToday({
    this.sessionDate,
    required this.sessionSource,
    this.meetingSessionId,
    required this.courseClassId,
    required this.courseCode,
    required this.courseName,
    this.lecturerName,
    required this.startTime,
    required this.endTime,
    required this.mode,
    this.locationName,
    this.meetingUrl,
    required this.sessionStatus,
    this.attendanceId,
    this.attendanceStatus,
    this.checkInAt,
    this.checkOutAt,
    this.minutesLate,
    this.checkInLatitude,
    this.checkInLongitude,
  });

  bool get sudahClockIn => attendanceId != null;
  bool get sudahClockOut => checkOutAt != null;
  bool get isCancelled => sessionStatus == 'CANCELLED';

  static String _hhmm(String pgTime) => pgTime.length >= 5 ? pgTime.substring(0, 5) : pgTime;
  String get startTimeLabel => _hhmm(startTime);
  String get endTimeLabel => _hhmm(endTime);

  bool isActiveNow() {
    if (isCancelled) return false;
    final now = DateTime.now();
    final start = _timeToday(startTime, now);
    final end = _timeToday(endTime, now);
    if (start == null || end == null) return false;
    return !now.isBefore(start) && now.isBefore(end);
  }

  static DateTime? _timeToday(String hhmmss, DateTime now) {
    final parts = hhmmss.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(now.year, now.month, now.day, h, m);
  }

  factory SessionToday.fromRow(Map<String, dynamic> row) {
    return SessionToday(
      sessionDate: row['session_date'] != null ? DateTime.parse(row['session_date'] as String) : null,
      sessionSource: row['session_source'] as String,
      meetingSessionId: row['meeting_session_id'] as String?,
      courseClassId: row['course_class_id'] as String,
      courseCode: row['course_code'] as String? ?? '',
      courseName: row['course_name'] as String? ?? '',
      lecturerName: row['lecturer_name'] as String?,
      startTime: row['start_time'] as String,
      endTime: row['end_time'] as String,
      mode: row['mode'] as String,
      locationName: row['location_name'] as String?,
      meetingUrl: row['meeting_url'] as String?,
      sessionStatus: row['session_status'] as String,
      attendanceId: row['attendance_id'] as String?,
      attendanceStatus: row['attendance_status'] as String?,
      checkInAt: row['check_in_at'] != null ? DateTime.parse(row['check_in_at'] as String) : null,
      checkOutAt: row['check_out_at'] != null ? DateTime.parse(row['check_out_at'] as String) : null,
      minutesLate: (row['minutes_late'] as num?)?.toInt(),
      checkInLatitude: (row['check_in_latitude'] as num?)?.toDouble(),
      checkInLongitude: (row['check_in_longitude'] as num?)?.toDouble(),
    );
  }
}
