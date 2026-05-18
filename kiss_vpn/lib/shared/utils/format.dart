class Format {
  static String bytes(int bytes, {int decimals = 1}) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
    double value = bytes.toDouble();
    int i = -1;
    do {
      value /= 1024;
      i++;
    } while (value >= 1024 && i < units.length - 1);
    return '${value.toStringAsFixed(decimals)} ${units[i]}';
  }

  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
