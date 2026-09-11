import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/repositories/schedule_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../models/academic_event_model.dart';
import '../../models/session_today_model.dart';

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  final _repo = ScheduleRepository();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<SessionToday>> _sesi = {};
  Map<DateTime, List<AcademicEvent>> _libur = {};
  bool _loading = true;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    _muatBulan(_focusedDay);
  }

  Future<void> _muatBulan(DateTime bulan) async {
    setState(() => _loading = true);
    final awal = DateTime(bulan.year, bulan.month, 1).subtract(const Duration(days: 7));
    final akhir = DateTime(bulan.year, bulan.month + 1, 0).add(const Duration(days: 7));
    final results = await Future.wait([
      _repo.sessionsForStudentBetween(awal, akhir),
      _repo.academicEventsBetween(awal, akhir),
    ]);
    final sesiList = results[0] as List<SessionToday>;
    final liburList = results[1] as List<AcademicEvent>;

    final sesi = <DateTime, List<SessionToday>>{};
    for (final s in sesiList) {
      if (s.sessionDate == null) continue;
      sesi.putIfAbsent(_dateOnly(s.sessionDate!), () => []).add(s);
    }
    final libur = <DateTime, List<AcademicEvent>>{};
    for (final e in liburList) {
      libur.putIfAbsent(_dateOnly(e.date), () => []).add(e);
    }
    if (mounted) setState(() { _sesi = sesi; _libur = libur; _loading = false; });
  }

  List<SessionToday> _sesiPadaHari(DateTime day) => _sesi[_dateOnly(day)] ?? [];
  List<AcademicEvent> _liburPadaHari(DateTime day) => _libur[_dateOnly(day)] ?? [];
  bool _isHari(DateTime day) => _liburPadaHari(day).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final hari = _selectedDay ?? DateTime.now();
    final sesiTerpilih = _sesiPadaHari(hari);
    final liburTerpilih = _liburPadaHari(hari);

    return Column(
      children: [
        TableCalendar<SessionToday>(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          locale: 'id_ID',
          selectedDayPredicate: (day) => _selectedDay != null && isSameDay(_selectedDay!, day),
          eventLoader: _sesiPadaHari,
          holidayPredicate: _isHari,
          calendarStyle: CalendarStyle(
            markerDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            todayDecoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
            holidayTextStyle: TextStyle(color: AppTheme.danger),
            holidayDecoration: BoxDecoration(
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          onDaySelected: (selected, focused) {
            setState(() { _selectedDay = selected; _focusedDay = focused; });
            _bukaDetailHari(context, selected);
          },
          onPageChanged: (focused) {
            _focusedDay = focused;
            _muatBulan(focused);
          },
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        const Divider(height: 1),
        Expanded(
          child: (sesiTerpilih.isEmpty && liburTerpilih.isEmpty)
              ? const Center(child: Text('Tidak ada jadwal di tanggal ini'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...liburTerpilih.map((e) => _LiburCard(event: e)),
                    ...sesiTerpilih.map((s) => _JadwalCard(sesi: s)),
                  ],
                ),
        ),
      ],
    );
  }

  void _bukaDetailHari(BuildContext context, DateTime day) {
    final sesiList = _sesiPadaHari(day);
    final liburList = _liburPadaHari(day);
    if (sesiList.isEmpty && liburList.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${day.day}/${day.month}/${day.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...liburList.map((e) => _LiburCard(event: e)),
            ...sesiList.map((s) => _JadwalCard(sesi: s)),
          ],
        ),
      ),
    );
  }
}

class _LiburCard extends StatelessWidget {
  const _LiburCard({required this.event});
  final AcademicEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.danger.withValues(alpha: 0.06),
      child: ListTile(
        leading: const Icon(Icons.flag_outlined, color: AppTheme.danger),
        title: Text(event.title),
        subtitle: const Text('Hari Libur Nasional'),
      ),
    );
  }
}

class _JadwalCard extends StatelessWidget {
  const _JadwalCard({required this.sesi});
  final SessionToday sesi;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.book_outlined),
        title: Text(sesi.courseName),
        subtitle: Text(
          '${sesi.startTimeLabel} - ${sesi.endTimeLabel} • '
          '${sesi.mode == 'ONLINE' ? 'Online' : sesi.locationName ?? 'Offline'}'
          '${sesi.lecturerName != null ? '\nDosen: ${sesi.lecturerName}' : ''}'
          '${sesi.sessionStatus == 'RESCHEDULED' ? '\nJadwal berubah dari sesi reguler' : ''}'
          '${sesi.isCancelled ? '\nSesi ini dibatalkan' : ''}',
        ),
        isThreeLine: true,
        trailing: sesi.isCancelled
            ? const Chip(label: Text('Batal', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFFFDE2E2))
            : null,
      ),
    );
  }
}
