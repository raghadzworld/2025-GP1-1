import 'dart:typed_data';

/// Wraps raw 16-bit PCM audio bytes in a standard 44-byte RIFF/WAVE header.
Uint8List pcm16ToWav(
  Uint8List pcmData, {
  int sampleRate = 16000,
  int channels = 1,
}) {
  const bitsPerSample = 16;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final byteRate = sampleRate * blockAlign;
  final dataSize = pcmData.length;

  final header = ByteData(44);
  void writeString(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  header.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // fmt chunk size
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  writeString(36, 'data');
  header.setUint32(40, dataSize, Endian.little);

  final wav = BytesBuilder();
  wav.add(header.buffer.asUint8List());
  wav.add(pcmData);
  return wav.toBytes();
}

/// Normalized (0.0–1.0) peak amplitude of a chunk of little-endian 16-bit PCM samples.
double pcm16PeakAmplitude(Uint8List pcmData) {
  if (pcmData.length < 2) return 0.0;
  final samples = ByteData.sublistView(pcmData);
  var peak = 0;
  for (var i = 0; i + 1 < pcmData.length; i += 2) {
    final sample = samples.getInt16(i, Endian.little).abs();
    if (sample > peak) peak = sample;
  }
  return (peak / 32768.0).clamp(0.0, 1.0);
}
