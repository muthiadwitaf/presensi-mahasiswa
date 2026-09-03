import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/jadwal_model.dart';
import '../../models/matkul_model.dart';
import '../../models/ruang_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jadwal_provider.dart';
import '../../widgets/empty_state.dart';

/// Karena belum ada integrasi SIAKAD, dosen mengelola matkul/ruang(+koordinat
/// geofence)/jadwal langsung lewat app supaya alur presensi & menu Jadwal
/// Kuliah punya sumber data tanpa perlu edit Firestore console manual.
class KelolaJadwalScreen extends StatelessWidget {
  const KelolaJadwalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JadwalProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Mata Kuliah', icon: Icons.menu_book, onAdd: () => _formMatkul(context)),
        const SizedBox(height: 10),
        if (provider.matkulList.isEmpty)
          const EmptyState(message: 'Belum ada mata kuliah', icon: Icons.menu_book_outlined)
        else
          ...provider.matkulList.map((m) => Card(
                child: ListTile(
                  leading: const _IconBubble(icon: Icons.menu_book, color: AppTheme.primary),
                  title: Text(m.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Dosen: ${m.dosenNama}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    onPressed: () => context.read<JadwalProvider>().hapusMatkul(m.id),
                  ),
                ),
              )),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Ruang Kelas', icon: Icons.meeting_room, onAdd: () => _formRuang(context)),
        const SizedBox(height: 10),
        if (provider.ruangList.isEmpty)
          const EmptyState(message: 'Belum ada ruang kelas', icon: Icons.meeting_room_outlined)
        else
          ...provider.ruangList.map((r) => Card(
                child: ListTile(
                  leading: const _IconBubble(icon: Icons.meeting_room, color: AppTheme.success),
                  title: Text(r.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(r.gedung),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    onPressed: () => context.read<JadwalProvider>().hapusRuang(r.id),
                  ),
                ),
              )),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Jadwal', icon: Icons.event_note, onAdd: () => _formJadwal(context)),
        const SizedBox(height: 10),
        if (provider.jadwalList.isEmpty)
          const EmptyState(message: 'Belum ada jadwal', icon: Icons.event_busy_outlined)
        else
          ...provider.jadwalList.map((j) => Card(
                child: ListTile(
                  leading: const _IconBubble(icon: Icons.event_note, color: AppTheme.warning),
                  title: Text(j.matkulNama, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${j.hariLabel}, ${j.jamMulai}-${j.jamSelesai} • ${j.ruangNama}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    onPressed: () => context.read<JadwalProvider>().hapusJadwal(j.id),
                  ),
                ),
              )),
      ],
    );
  }

  void _formMatkul(BuildContext context) {
    final namaController = TextEditingController();
    final dosen = context.read<AuthProvider>().currentUser!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Mata Kuliah'),
        content: TextField(
          controller: namaController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama Mata Kuliah', prefixIcon: Icon(Icons.menu_book)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (namaController.text.trim().isEmpty) return;
              context.read<JadwalProvider>().tambahMatkul(MatkulModel(
                    id: '',
                    nama: namaController.text.trim(),
                    dosenUid: dosen.uid,
                    dosenNama: dosen.nama,
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _formRuang(BuildContext context) {
    final namaController = TextEditingController();
    final gedungController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Ruang Kelas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: namaController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama Ruang', prefixIcon: Icon(Icons.meeting_room)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gedungController,
              decoration: const InputDecoration(labelText: 'Gedung', prefixIcon: Icon(Icons.apartment)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (namaController.text.trim().isEmpty) return;
              context.read<JadwalProvider>().tambahRuang(RuangModel(
                    id: '',
                    nama: namaController.text.trim(),
                    gedung: gedungController.text.trim(),
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _formJadwal(BuildContext context) {
    final provider = context.read<JadwalProvider>();
    final dosen = context.read<AuthProvider>().currentUser!;
    MatkulModel? matkul = provider.matkulList.isNotEmpty ? provider.matkulList.first : null;
    RuangModel? ruang = provider.ruangList.isNotEmpty ? provider.ruangList.first : null;
    int hari = DateTime.now().weekday;
    final jamMulaiController = TextEditingController(text: '08:00');
    final jamSelesaiController = TextEditingController(text: '10:00');

    if (matkul == null || ruang == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tambahkan Mata Kuliah & Ruang terlebih dahulu')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tambah Jadwal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<MatkulModel>(
                  initialValue: matkul,
                  decoration: const InputDecoration(labelText: 'Mata Kuliah'),
                  items: provider.matkulList
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.nama)))
                      .toList(),
                  onChanged: (v) => setState(() => matkul = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RuangModel>(
                  initialValue: ruang,
                  decoration: const InputDecoration(labelText: 'Ruang'),
                  items: provider.ruangList
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                      .toList(),
                  onChanged: (v) => setState(() => ruang = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: hari,
                  decoration: const InputDecoration(labelText: 'Hari'),
                  items: JadwalModel.namaHari.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => hari = v ?? hari),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: jamMulaiController,
                        decoration: const InputDecoration(labelText: 'Jam Mulai'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: jamSelesaiController,
                        decoration: const InputDecoration(labelText: 'Jam Selesai'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                provider.tambahJadwal(JadwalModel(
                  id: '',
                  matkulId: matkul!.id,
                  matkulNama: matkul!.nama,
                  dosenNama: dosen.nama,
                  ruangId: ruang!.id,
                  ruangNama: ruang!.nama,
                  hari: hari,
                  jamMulai: jamMulaiController.text.trim(),
                  jamSelesai: jamSelesaiController.text.trim(),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon, required this.onAdd});
  final String title;
  final IconData icon;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
        ),
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
