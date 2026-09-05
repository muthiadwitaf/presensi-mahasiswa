import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/academic_reference_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_background.dart';

/// Pilihan role di UI - beda dari [UserRole] karena "Koordinator Kelas"
/// BUKAN nilai users.role (tetap berbasis akun mahasiswa + penugasan
/// role_assignments per class_group, lihat
/// `supabase/migrations/0024_self_register_coordinator.sql`).
enum _PilihanRole { mahasiswa, dosen, koordinator }

/// Registrasi mandiri - role dipilih sendiri (mahasiswa/dosen/koordinator
/// kelas), bukan admin. Ini keputusan produk yang sadar akan trade-off
/// keamanannya (siapa saja bisa mendaftar sebagai "dosen"/"koordinator"
/// tanpa verifikasi identitas kampus) - lihat catatan di
/// `supabase/migrations/0018_self_registration_and_coordinator.sql` dan
/// `SupabaseAuthService.register`. Cocok untuk kebutuhan demo/skripsi,
/// TIDAK untuk deployment produksi sungguhan.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nimController = TextEditingController();
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();
  _PilihanRole _pilihan = _PilihanRole.mahasiswa;

  final _academicRepo = AcademicReferenceRepository();
  late final Future<List<StudyProgramOption>> _studyProgramsFuture;
  late final Future<List<ClassGroupOption>> _classGroupsFuture;
  String? _studyProgramId;
  String? _classGroupId;

  bool get _butuhProdi => _pilihan == _PilihanRole.mahasiswa || _pilihan == _PilihanRole.koordinator;
  bool get _isKoordinator => _pilihan == _PilihanRole.koordinator;
  UserRole get _role => _pilihan == _PilihanRole.dosen ? UserRole.dosen : UserRole.mahasiswa;

  @override
  void initState() {
    super.initState();
    _studyProgramsFuture = _academicRepo.fetchStudyPrograms();
    _classGroupsFuture = _academicRepo.fetchClassGroups();
  }

  @override
  void dispose() {
    _nimController.dispose();
    _namaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_butuhProdi && _studyProgramId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program studi wajib dipilih')),
      );
      return;
    }
    if (_isKoordinator && _classGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kelas yang dikoordinasikan wajib dipilih')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      nim: _nimController.text.trim(),
      nama: _namaController.text.trim(),
      password: _passwordController.text,
      role: _role,
      studyProgramId: _studyProgramId,
      isCoordinator: _isKoordinator,
      classGroupId: _isKoordinator ? _classGroupId : null,
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
    } else if (mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54),
      filled: true,
      fillColor: const Color(0xFFE8F0FE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text('Daftar Akun', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _namaController,
                                style: const TextStyle(color: Colors.black87),
                                decoration: _decoration('Nama Lengkap'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _nimController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.black87),
                                decoration: _decoration('NIM / NIP'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'NIM/NIP wajib diisi' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                style: const TextStyle(color: Colors.black87),
                                decoration: _decoration('Kata Sandi'),
                                validator: (v) =>
                                    (v == null || v.length < 8) ? 'Kata sandi minimal 8 karakter' : null,
                              ),
                              const SizedBox(height: 18),
                              Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(
                                        secondaryContainer: AppTheme.primary,
                                        onSecondaryContainer: Colors.white,
                                      ),
                                ),
                                child: SegmentedButton<_PilihanRole>(
                                  segments: const [
                                    ButtonSegment(value: _PilihanRole.mahasiswa, label: Text('Mahasiswa'), icon: Icon(Icons.school)),
                                    ButtonSegment(value: _PilihanRole.dosen, label: Text('Dosen'), icon: Icon(Icons.person)),
                                    ButtonSegment(
                                      value: _PilihanRole.koordinator,
                                      label: Text('Koordinator'),
                                      icon: Icon(Icons.groups_outlined),
                                    ),
                                  ],
                                  selected: {_pilihan},
                                  onSelectionChanged: (v) => setState(() => _pilihan = v.first),
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (_butuhProdi)
                                FutureBuilder<List<StudyProgramOption>>(
                                  future: _studyProgramsFuture,
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: LinearProgressIndicator(),
                                      );
                                    }
                                    final options = snapshot.data!;
                                    return DropdownButtonFormField<String>(
                                      initialValue: _studyProgramId,
                                      decoration: _decoration('Program Studi'),
                                      items: options
                                          .map((o) => DropdownMenuItem(value: o.id, child: Text('${o.code} - ${o.name}')))
                                          .toList(),
                                      onChanged: (v) => setState(() => _studyProgramId = v),
                                      validator: (v) => (_butuhProdi && v == null) ? 'Program studi wajib dipilih' : null,
                                    );
                                  },
                                ),
                              if (_isKoordinator) ...[
                                const SizedBox(height: 14),
                                FutureBuilder<List<ClassGroupOption>>(
                                  future: _classGroupsFuture,
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: LinearProgressIndicator(),
                                      );
                                    }
                                    final options = snapshot.data!;
                                    return DropdownButtonFormField<String>(
                                      initialValue: _classGroupId,
                                      decoration: _decoration('Kelas yang Dikoordinasikan'),
                                      items: options
                                          .map((o) => DropdownMenuItem(value: o.id, child: Text('${o.code} - ${o.name}')))
                                          .toList(),
                                      onChanged: (v) => setState(() => _classGroupId = v),
                                      validator: (v) =>
                                          (_isKoordinator && v == null) ? 'Kelas wajib dipilih' : null,
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: auth.isBusy ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: auth.isBusy
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Daftar', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
