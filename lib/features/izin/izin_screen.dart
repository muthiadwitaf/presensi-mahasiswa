import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/schedule_repository.dart';
import '../../models/izin_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../widgets/empty_state.dart';

class IzinScreen extends StatefulWidget {
  const IzinScreen({super.key});

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen> {
  StatusIzin? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<IzinProvider>().refreshMine());
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final izinProvider = context.watch<IzinProvider>();
    final list = _filter == null ? izinProvider.mine : izinProvider.mine.where((e) => e.status == _filter).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'Semua', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Menunggu',
                    selected: _filter == StatusIzin.pending,
                    onTap: () => setState(() => _filter = StatusIzin.pending),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Disetujui',
                    selected: _filter == StatusIzin.disetujui,
                    onTap: () => setState(() => _filter = StatusIzin.disetujui),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Ditolak',
                    selected: _filter == StatusIzin.ditolak,
                    onTap: () => setState(() => _filter = StatusIzin.ditolak),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: izinProvider.refreshMine,
              child: list.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (izinProvider.isLoading)
                          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                        else
                          const EmptyState(message: 'Belum ada pengajuan izin/sakit', icon: Icons.event_note_outlined),
                      ],
                    )
                  : _buildListPerSemester(context, list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaFormIzin(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajukan Izin'),
      ),
    );
  }

  Widget _buildListPerSemester(BuildContext context, List<IzinModel> list) {
    final Map<String, List<IzinModel>> perSemester = {};
    for (final izin in list) {
      perSemester.putIfAbsent(izin.semesterLabel, () => []).add(izin);
    }
    final semesters = perSemester.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final semester in semesters) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              semester,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...perSemester[semester]!.map((izin) => Card(
                child: ListTile(
                  leading: Icon(
                    izin.jenis == JenisIzin.sakit ? Icons.sick_outlined : Icons.event_note_outlined,
                    color: Colors.grey.shade600,
                  ),
                  title: Text(izin.matkulNama),
                  subtitle: Text(
                    '${izin.jenis == JenisIzin.sakit ? 'Sakit' : 'Izin'} • '
                    '${DateFormat('d MMM y', 'id_ID').format(izin.tanggal)}\n${izin.alasan}',
                  ),
                  isThreeLine: true,
                  trailing: _StatusChip(status: izin.status),
                  onTap: () => _bukaDetail(context, izin),
                ),
              )),
        ],
      ],
    );
  }

  void _bukaFormIzin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FormIzinSheet(),
    );
  }

  void _bukaDetail(BuildContext context, IzinModel izin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetailIzinSheet(izin: izin),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final StatusIzin status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      StatusIzin.pending => (Colors.orange, 'Menunggu'),
      StatusIzin.disetujui => (Colors.green, 'Disetujui'),
      StatusIzin.ditolak => (Colors.red, 'Ditolak'),
      StatusIzin.dibatalkan => (Colors.grey, 'Dibatalkan'),
    };
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}

class _DetailIzinSheet extends StatelessWidget {
  const _DetailIzinSheet({required this.izin});
  final IzinModel izin;

  @override
  Widget build(BuildContext context) {
    final izinProvider = context.read<IzinProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(izin.matkulNama, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              _StatusChip(status: izin.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(izin.jenis == JenisIzin.sakit ? 'Sakit' : 'Izin', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          _DetailRow(label: 'Tanggal', value: DateFormat('EEEE, d MMM y', 'id_ID').format(izin.tanggal)),
          _DetailRow(label: 'Diajukan', value: DateFormat('d MMM y, HH:mm', 'id_ID').format(izin.createdAt)),
          _DetailRow(label: 'Alasan', value: izin.alasan),
          if (izin.attachmentPath != null) ...[
            const SizedBox(height: 12),
            const Text('Bukti', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            FutureBuilder<String>(
              future: izinProvider.attachmentSignedUrl(izin.attachmentPath!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(snapshot.data!, height: 180, fit: BoxFit.cover),
                );
              },
            ),
          ],
          if (izin.status != StatusIzin.pending) ...[
            const Divider(height: 28),
            if (izin.reviewedAt != null)
              _DetailRow(label: 'Ditinjau', value: DateFormat('d MMM y, HH:mm', 'id_ID').format(izin.reviewedAt!)),
            if (izin.reviewNote != null && izin.reviewNote!.isNotEmpty)
              _DetailRow(label: 'Catatan', value: izin.reviewNote!),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _FormIzinSheet extends StatefulWidget {
  const _FormIzinSheet();

  @override
  State<_FormIzinSheet> createState() => _FormIzinSheetState();
}

class _FormIzinSheetState extends State<_FormIzinSheet> {
  final _formKey = GlobalKey<FormState>();
  final _alasanController = TextEditingController();
  final _scheduleRepo = ScheduleRepository();
  late final Future<List<EnrolledCourseOption>> _matkulFuture = _scheduleRepo.myActiveCourseClasses();
  EnrolledCourseOption? _matkul;
  JenisIzin _jenis = JenisIzin.izin;
  DateTime _tanggal = DateTime.now();
  File? _bukti;

  Future<void> _pilihBukti(ImageSource source) async {
    final xfile = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (xfile != null) setState(() => _bukti = File(xfile.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _matkul == null) {
      if (_matkul == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih mata kuliah terlebih dahulu')));
      }
      return;
    }
    final izinProvider = context.read<IzinProvider>();
    final ok = await izinProvider.ajukanIzin(
      jadwalId: _matkul!.courseClassId,
      jenis: _jenis,
      tanggal: _tanggal,
      alasan: _alasanController.text.trim(),
      bukti: _bukti,
    );
    if (ok && mounted) {
      Navigator.pop(context);
    } else if (mounted && izinProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(izinProvider.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final izinProvider = context.watch<IzinProvider>();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ajukan Izin/Sakit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SegmentedButton<JenisIzin>(
              segments: const [
                ButtonSegment(value: JenisIzin.izin, label: Text('Izin'), icon: Icon(Icons.event_note_outlined)),
                ButtonSegment(value: JenisIzin.sakit, label: Text('Sakit'), icon: Icon(Icons.sick_outlined)),
              ],
              selected: {_jenis},
              onSelectionChanged: (s) => setState(() => _jenis = s.first),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<EnrolledCourseOption>>(
              future: _matkulFuture,
              builder: (context, snapshot) {
                final options = snapshot.data ?? [];
                return DropdownButtonFormField<EnrolledCourseOption>(
                  initialValue: _matkul,
                  decoration: const InputDecoration(labelText: 'Mata Kuliah'),
                  items: options
                      .map((o) => DropdownMenuItem(value: o, child: Text('${o.courseCode} - ${o.courseName}')))
                      .toList(),
                  onChanged: (v) => setState(() => _matkul = v),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Tanggal: ${DateFormat('d MMM y', 'id_ID').format(_tanggal)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _tanggal,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _tanggal = picked);
              },
            ),
            TextFormField(
              controller: _alasanController,
              decoration: const InputDecoration(labelText: 'Alasan'),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Alasan wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihBukti(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Foto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihBukti(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
            if (_bukti != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Bukti terlampir: ${_bukti!.path.split(Platform.pathSeparator).last}'),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: izinProvider.isSubmitting ? null : _submit,
              child: izinProvider.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kirim Pengajuan'),
            ),
          ],
        ),
      ),
    );
  }
}
