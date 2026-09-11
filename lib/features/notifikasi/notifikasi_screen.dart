import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/notifikasi_repository.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifikasi_provider.dart';
import '../../widgets/empty_state.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotifikasiProvider>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final provider = context.watch<NotifikasiProvider>();
    final isDosen = user?.role == UserRole.dosen;
    final list = provider.items;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: list.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (provider.isLoading)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                  else
                    const EmptyState(message: 'Belum ada pengumuman', icon: Icons.notifications_none),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final n = list[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(n.judul, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${n.isi}\n${DateFormat('d MMM y, HH:mm', 'id_ID').format(n.createdAt)} • ${n.createdByNama}'),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: isDosen
          ? FloatingActionButton.extended(
              onPressed: () => _bukaFormPengumuman(context, user!.nama),
              icon: const Icon(Icons.add),
              label: const Text('Buat Pengumuman'),
            )
          : null,
    );
  }

  void _bukaFormPengumuman(BuildContext context, String namaDosen) {
    final judulController = TextEditingController();
    final isiController = TextEditingController();
    final notifikasiProvider = context.read<NotifikasiProvider>();
    TaughtCourseOption? kelasTujuan;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Buat Pengumuman'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<List<TaughtCourseOption>>(
                  future: notifikasiProvider.myTaughtCourseClasses(),
                  builder: (context, snapshot) {
                    final options = snapshot.data ?? [];
                    return DropdownButtonFormField<TaughtCourseOption>(
                      initialValue: kelasTujuan,
                      decoration: const InputDecoration(labelText: 'Kelas Tujuan'),
                      items: options
                          .map((o) => DropdownMenuItem(value: o, child: Text(o.courseName)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => kelasTujuan = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: judulController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Judul', prefixIcon: Icon(Icons.title)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: isiController,
                  decoration: const InputDecoration(
                    labelText: 'Isi',
                    prefixIcon: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.notes)),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (judulController.text.trim().isEmpty || kelasTujuan == null) return;
                notifikasiProvider.buatPengumuman(
                  judul: judulController.text.trim(),
                  isi: isiController.text.trim(),
                  createdByNama: namaDosen,
                  targetCourseClassId: kelasTujuan!.courseClassId,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }
}
