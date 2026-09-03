import 'package:flutter/foundation.dart';

import '../core/repositories/notifikasi_repository.dart';
import '../models/notifikasi_model.dart';

class NotifikasiProvider extends ChangeNotifier {
  NotifikasiProvider({NotifikasiRepository? repository})
      : _repo = repository ?? NotifikasiRepository();

  final NotifikasiRepository _repo;

  Stream<List<NotifikasiModel>> watchAll() => _repo.watchAll();

  Future<void> buatPengumuman({required String judul, required String isi, required String createdByNama}) {
    return _repo.buat(NotifikasiModel(
      id: '',
      judul: judul,
      isi: isi,
      createdByNama: createdByNama,
      createdAt: DateTime.now(),
    ));
  }
}
