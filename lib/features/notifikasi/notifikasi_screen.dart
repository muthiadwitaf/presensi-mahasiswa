import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/notifikasi_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifikasi_provider.dart';
import '../../widgets/empty_state.dart';

class NotifikasiScreen extends StatelessWidget {
  const NotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final provider = context.watch<NotifikasiProvider>();
    final isDosen = user?.role == UserRole.dosen;

    return Scaffold(
      body: StreamBuilder<List<NotifikasiModel>>(
        stream: provider.watchAll(),
        builder: (context, snapshot) {
          final list = snapshot.data ?? [];
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return const EmptyState(message: 'Belum ada pengumuman', icon: Icons.notifications_none);
          }
          return ListView.builder(
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
          );
        },
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Pengumuman'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              if (judulController.text.trim().isEmpty) return;
              context.read<NotifikasiProvider>().buatPengumuman(
                    judul: judulController.text.trim(),
                    isi: isiController.text.trim(),
                    createdByNama: namaDosen,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }
}
