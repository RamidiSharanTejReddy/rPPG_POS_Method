import 'dart:math';

class POSProcessor {
  // Stores the last 128 POS values (power of 2 for FFT)
  static const int windowSize = 64;
  final List<double> _posValues = [];

  // Expose POS values for external access (read/write)
  List<double> get posValues => _posValues;

  // Add a new frame's RGB mean values
  void addFrame(double r, double g, double b) {
    // POS algorithm: project RGB onto plane orthogonal to skin tone
    // S = 3*R - 2*G
    // H = 1.5*R + G - 1.5*B
    double s = 3 * r - 2 * g;
    double h = 1.5 * r + g - 1.5 * b;
    double posValue = atan2(h, s);
    // print('Adding frame: R=$r, G=$g, B=$b, POS value=$posValue');
    _posValues.add(posValue);
    if (_posValues.length > windowSize) {
      _posValues.removeAt(0);
    }
  }

  // Calculate BPM from the last 30 POS values (1 second window)
  double? calculateBPM({void Function(String)? debug}) {
    print("calculateBPM called with ${_posValues.length} values");
    if (_posValues.length < windowSize) {
      print("Not enough POS values for BPM calculation");
      return null;
    }
    final samplingRate = 30.0; // 30 FPS
    final N = windowSize;
    print("Step 1: Remove DC");
    final mean = _posValues.reduce((a, b) => a + b) / N;
    final windowZeroMean = _posValues.map((v) => v - mean).toList();
    print("Step 2: FFT");
    List<double> re = List.from(windowZeroMean.take(windowSize));
    List<double> im = List.filled(windowSize, 0.0);
    // _fft(re, im);
    print("Step 3: Magnitude spectrum");
    List<double> mag = List.generate(N ~/ 2, (i) => sqrt(re[i] * re[i] + im[i] * im[i]));
    print("Step 4: Frequency axis");
    List<double> freqs = List.generate(mag.length, (i) => i * samplingRate / N);
    print("Step 5: Find peak in physiological range");
    final minHz = 0.7;
    final maxHz = 4.0;
    final maxValidHz = 110.0 / 60.0; // 1.833 Hz
    int minIdx = freqs.indexWhere((f) => f >= minHz);
    int maxIdx = freqs.indexWhere((f) => f > maxHz);
    if (minIdx == -1) minIdx = 0;
    if (maxIdx == -1) maxIdx = mag.length;
    // Find the highest peak <= 110 BPM (<= 1.833 Hz)
    double maxMag = -1;
    int maxMagIdx = -1;
    for (int i = minIdx; i < maxIdx; i++) {
      double bpmCandidate = freqs[i] * 60.0;
      if (bpmCandidate <= 110 && mag[i] > maxMag) {
        maxMag = mag[i];
        maxMagIdx = i;
      }
    }
    // If no valid peak found, try the next highest in the range (even if >110 BPM)
    if (maxMagIdx == -1) {
      for (int i = minIdx; i < maxIdx; i++) {
        if (mag[i] > maxMag) {
          maxMag = mag[i];
          maxMagIdx = i;
        }
      }
    }
    // Parabolic interpolation for more precise peak frequency
    double? freqHz;
    double? bpm;
    if (maxMagIdx != -1) {
      double interpIdx = maxMagIdx.toDouble();
      if (maxMagIdx > 0 && maxMagIdx < mag.length - 1) {
        double alpha = mag[maxMagIdx - 1];
        double beta = mag[maxMagIdx];
        double gamma = mag[maxMagIdx + 1];
        double p = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma);
        interpIdx = maxMagIdx + p;
      }
      freqHz = interpIdx * samplingRate / N;
      bpm = freqHz * 60.0;
      print("Step 7: Peak frequency (interpolated): $freqHz Hz, BPM: $bpm");
      if (freqHz < minHz || freqHz > maxHz) {
        print("Step 8: Peak frequency out of range");
        bpm = null;
      }
    } else {
      print("Step 6b: No peak found in range");
    }
    // Log all frequencies and their magnitudes
    List<MapEntry<double, double>> freqMagPairs = List.generate(mag.length, (i) => MapEntry(freqs[i], mag[i]));
    String allFreqs = freqMagPairs.map((e) => '${e.key.toStringAsFixed(2)}Hz: ${e.value.toStringAsFixed(2)}').join(', ');
    String debugMsg = 'Window mean: ${mean.toStringAsFixed(4)}\nMax FFT mag: ${maxMag.toStringAsFixed(4)} at ${freqHz?.toStringAsFixed(3) ?? "-"} Hz (${bpm?.toStringAsFixed(1) ?? "-"} BPM)\nAll freqs: $allFreqs';
    if (debug != null) {
      debug(debugMsg);
    }
    print("Calculated"+debugMsg);
    return bpm;
  }

  // Minimal Cooley-Tukey FFT (in-place, radix-2, real input)
  void _fft(List<double> re, List<double> im) {
    int n = re.length;
    if (n <= 1) return;
    print("_fft: Bit-reversal permutation");
    int j = 0;
    for (int i = 0; i < n; i++) {
      if (i < j) {
        double tmpRe = re[i];
        double tmpIm = im[i];
        re[i] = re[j];
        im[i] = im[j];
        re[j] = tmpRe;
        im[j] = tmpIm;
      }
      int m = n >> 1;
      while (j >= m && m >= 2) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }
    print("_fft: Starting FFT stages");
    for (int len = 2; len <= n; len <<= 1) {
      double ang = -2 * pi / len;
      double wlenRe = cos(ang);
      double wlenIm = sin(ang);
      print("_fft: Stage len=$len");
      for (int i = 0; i < n; i += len) {
        double wRe = 1, wIm = 0;
        for (int j = 0; j < len ~/ 2; j++) {
          int u = i + j;
          int v = i + j + len ~/ 2;
          double tRe = re[v] * wRe - im[v] * wIm;
          double tIm = re[v] * wIm + im[v] * wRe;
          re[v] = re[u] - tRe;
          im[v] = im[u] - tIm;
          re[u] += tRe;
          im[u] += tIm;
          double nextWRe = wRe * wlenRe - wIm * wlenIm;
          wIm = wRe * wlenIm + wIm * wlenRe;
          wRe = nextWRe;
        }
        if (i % 32 == 0) print("_fft: i=$i, len=$len");
      }
    }
    print("_fft: FFT complete");
  }

  // Get average BPM over all windows
  double averageBPM(List<double> bpmList) {
    if (bpmList.isEmpty) return 0;
    return bpmList.reduce((a, b) => a + b) / bpmList.length;
  }
}
