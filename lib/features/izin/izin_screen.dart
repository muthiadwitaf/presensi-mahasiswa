import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/izin_model.dart';
import '../../models/jadwal_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/jadwal_provider.dart';
import '../../widgets/empty_state.dart';

class IzinScreen extends StatelessWidget {
  const IzinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final izinProvider = context.watch<IzinProvider>();

    return Scaffold(
      body: StreamBuilder<List<IzinModel>>(
        stream: izinProvider.watchByMahasiswa(uid),
        builder: (context, snapshot) {
          final list = snapshot.data ?? [];
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return const EmptyState(message: 'Belum ada pengajuan izin/sakit', icon: Icons.event_note_outlined);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final izin = list[i];
              return Card(
                child: ListTile(
                  title: Text(izin.matkulNama),
                  subtitle: Text(
                    '${DateFormat('d MMM y', 'id_ID').format(izin.tanggal)}\n${izin.alasan}',
                  ),
                  isThreeLine: true,
                  trailing: _StatusChip(status: izin.status),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaFormIzin(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajukan Izin'),
      ),
    );
  }

  void _bukaFormIzin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FormIzinSheet(),
    );
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
    };
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
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
  JadwalModel? _jadwal;
  DateTime _tanggal = DateTime.now();
  File? _bukti;

  Future<void> _pilihBukti(ImageSource source) async {
    final xfile = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (xfile != null) setState(() => _bukti = File(xfile.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _jadwal == null) {
      if (_jadwal == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih mata kuliah terlebih dahulu')));
      }
      return;
    }
    final auth = context.read<AuthProvider>().currentUser!;
    final izinProvider = context.read<IzinProvider>();
    final ok = await izinProvider.ajukanIzin(
      mahasiswaUid: auth.uid,
      mahasiswaNama: auth.nama,
      mahasiswaNim: auth.nim,
      jadwalId: _jadwal!.id,
      matkulNama: _jadwal!.matkulNama,
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
    final jadwalList = context.watch<JadwalProvider>().jadwalList;
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
            DropdownButtonFormField<JadwalModel>(
              initialValue: _jadwal,
              decoration: const InputDecoration(labelText: 'Mata Kuliah'),
              items: jadwalList
                  .map((j) => DropdownMenuItem(value: j, child: Text('${j.matkulNama} (${j.hariLabel})')))
                  .toList(),
              onChanged: (v) => setState(() => _jadwal = v),
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
