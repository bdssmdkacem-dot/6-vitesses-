class SensorPerformanceStats {
  const SensorPerformanceStats({
    required this.elapsed,
    required this.events,
    required this.averageCallbackMicros,
    required this.maxCallbackMicros,
    required this.eventsPerSecond,
  });

  final Duration elapsed;
  final int events;
  final double averageCallbackMicros;
  final int maxCallbackMicros;
  final double eventsPerSecond;
}

class SensorPerformanceMonitor {
  final DateTime _startedAt = DateTime.now();
  int _events = 0;
  int _callbackMicros = 0;
  int _maxCallbackMicros = 0;

  void recordCallback(Duration duration) {
    final micros = duration.inMicroseconds;
    _events++;
    _callbackMicros += micros;
    if (micros > _maxCallbackMicros) _maxCallbackMicros = micros;
  }

  SensorPerformanceStats snapshot([DateTime? now]) {
    final current = now ?? DateTime.now();
    final elapsed = current.difference(_startedAt);
    final seconds = elapsed.inMicroseconds / 1000000.0;
    return SensorPerformanceStats(
      elapsed: elapsed,
      events: _events,
      averageCallbackMicros: _events == 0 ? 0 : _callbackMicros / _events,
      maxCallbackMicros: _maxCallbackMicros,
      eventsPerSecond: seconds <= 0 ? 0 : _events / seconds,
    );
  }
}
