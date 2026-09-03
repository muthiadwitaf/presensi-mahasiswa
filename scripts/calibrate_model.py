"""Kalibrasi model liveness (real/spoof) sebelum dipakai di app.

Model yang dipakai (biometric-technologies/liveness-detection-model, MIT)
punya satu neuron output sigmoid, dan dokumentasi sumbernya TIDAK menyebutkan
eksplisit arah label (skor mendekati 1 itu "real" atau "spoof"). Skrip ini
menjalankan model ke beberapa contoh foto wajah asli & foto/video spoof yang
SUDAH ANDA KETAHUI labelnya, lalu mencetak skornya supaya polaritas &
threshold bisa ditentukan secara empiris sebelum dipakai di aplikasi.

Cara pakai:
    pip install tensorflow pillow numpy
    python scripts/calibrate_model.py \
        --model assets/models/model.tflite \
        --real contoh_foto/real \
        --spoof contoh_foto/spoof

Siapkan dua folder berisi beberapa foto wajah (sudah di-crop wajahnya saja,
mirip yang akan dihasilkan pipeline Flutter): satu folder foto asli (real),
satu folder foto/video-capture spoof (foto dari layar HP/print out, dsb).

Setelah dapat hasilnya:
- Kalau skor rata-rata kelompok "real" JAUH LEBIH TINGGI dari kelompok
  "spoof" -> `realIsHighScore = true` di liveness_service.dart (default saat
  ini) sudah benar.
- Kalau sebaliknya (skor "real" lebih RENDAH) -> ubah jadi
  `realIsHighScore = false`.
- Set `threshold` di titik yang paling memisahkan dua kelompok (lihat print
  di akhir skrip untuk saran threshold sederhana berbasis titik tengah).
"""

from __future__ import annotations

import argparse
import glob
import os

import numpy as np
from PIL import Image

try:
    import tensorflow as tf
    Interpreter = tf.lite.Interpreter
except ImportError:  # fallback kalau hanya tflite-runtime yang terpasang
    from tflite_runtime.interpreter import Interpreter  # type: ignore

INPUT_SIZE = 224


def load_image(path: str) -> np.ndarray:
    img = Image.open(path).convert("RGB").resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.asarray(img, dtype=np.float32) / 255.0  # sesuai preprocessing kode Flutter
    return np.expand_dims(arr, axis=0)


def run_inference(interpreter: "Interpreter", arr: np.ndarray) -> float:
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    interpreter.set_tensor(input_details[0]["index"], arr)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]["index"])
    return float(np.squeeze(output))


def score_folder(interpreter: "Interpreter", folder: str) -> list[float]:
    scores = []
    for path in sorted(glob.glob(os.path.join(folder, "*"))):
        if not os.path.isfile(path):
            continue
        try:
            arr = load_image(path)
        except Exception as e:  # noqa: BLE001
            print(f"  (lewati {path}: {e})")
            continue
        score = run_inference(interpreter, arr)
        scores.append(score)
        print(f"  {os.path.basename(path):40s} skor = {score:.4f}")
    return scores


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="assets/models/model.tflite")
    parser.add_argument("--real", required=True, help="Folder berisi foto wajah ASLI")
    parser.add_argument("--spoof", required=True, help="Folder berisi foto/capture SPOOF")
    args = parser.parse_args()

    interpreter = Interpreter(model_path=args.model, num_threads=4)
    interpreter.allocate_tensors()

    print(f"\nModel: {args.model}\n")
    print("Kelompok REAL:")
    real_scores = score_folder(interpreter, args.real)
    print("\nKelompok SPOOF:")
    spoof_scores = score_folder(interpreter, args.spoof)

    if not real_scores or not spoof_scores:
        print("\nTidak cukup data di salah satu folder, kalibrasi dibatalkan.")
        return

    real_mean = float(np.mean(real_scores))
    spoof_mean = float(np.mean(spoof_scores))
    print(f"\nRata-rata skor REAL  : {real_mean:.4f}")
    print(f"Rata-rata skor SPOOF : {spoof_mean:.4f}")

    if real_mean > spoof_mean:
        print("\n=> Set `realIsHighScore = true;` di liveness_service.dart (skor tinggi = real).")
    else:
        print("\n=> Set `realIsHighScore = false;` di liveness_service.dart (skor rendah = real).")

    threshold = (real_mean + spoof_mean) / 2
    print(f"=> Saran awal `threshold = {threshold:.2f};` (titik tengah dua rata-rata; sesuaikan lagi berdasarkan uji precision/recall di skripsi Anda).")


if __name__ == "__main__":
    main()
