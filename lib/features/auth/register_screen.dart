import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_background.dart';

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
  UserRole _role = UserRole.mahasiswa;

  @override
  void dispose() {
    _nimController.dispose();
    _namaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      nim: _nimController.text.trim(),
      nama: _namaController.text.trim(),
      password: _passwordController.text,
      role: _role,
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
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Untuk keperluan demo purwarupa skripsi, peran (mahasiswa/dosen) '
                                  'dipilih sendiri saat mendaftar. Pada implementasi produksi, akun '
                                  'seharusnya diprovisikan oleh admin/SIAKAD.',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                                ),
                              ),
                              const SizedBox(height: 20),
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
                                    (v == null || v.length < 6) ? 'Kata sandi minimal 6 karakter' : null,
                              ),
                              const SizedBox(height: 18),
                              Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(
                                        secondaryContainer: AppTheme.primary,
                                        onSecondaryContainer: Colors.white,
                                      ),
                                ),
                                child: SegmentedButton<UserRole>(
                                  segments: const [
                                    ButtonSegment(value: UserRole.mahasiswa, label: Text('Mahasiswa'), icon: Icon(Icons.school)),
                                    ButtonSegment(value: UserRole.dosen, label: Text('Dosen'), icon: Icon(Icons.person)),
                                  ],
                                  selected: {_role},
                                  onSelectionChanged: (v) => setState(() => _role = v.first),
                                ),
                              ),
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
