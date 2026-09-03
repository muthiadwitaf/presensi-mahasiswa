class MatkulModel {
  final String id;
  final String nama;
  final String dosenUid;
  final String dosenNama;

  const MatkulModel({
    required this.id,
    required this.nama,
    required this.dosenUid,
    required this.dosenNama,
  });

  factory MatkulModel.fromMap(String id, Map<String, dynamic> map) {
    return MatkulModel(
      id: id,
      nama: map['nama'] as String? ?? '',
      dosenUid: map['dosenUid'] as String? ?? '',
      dosenNama: map['dosenNama'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'dosenUid': dosenUid,
      'dosenNama': dosenNama,
    };
  }
}
