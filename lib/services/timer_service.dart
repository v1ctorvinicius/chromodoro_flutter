import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../repositories/session_repository.dart';
import '../models/app_settings.dart';

enum TimerMode { focus, shortBreak, longBreak }

enum TimerState { idle, running, paused }

/// A project-bound Pomodoro timer.
///
/// The clock is driven by wall-clock timestamps (not by decrementing on each
/// tick) so it stays accurate even if the app is throttled. A session row is
/// created when focus starts and persisted (completed / interrupted) when the
/// phase ends.
class TimerService extends ChangeNotifier {
  final SessionRepository _sessionRepo;
  final AppSettings _settings;

  TimerMode _mode = TimerMode.focus;
  TimerState _state = TimerState.idle;
  int _remainingMs = 0;
  int _phaseTotalSec = 0;
  DateTime? _resumeAt;
  int _resumeRemainingMs = 0;
  int _completedCycles = 0;

  int? _activeProjectId;
  int? _lastProjectId;
  int? _activeSessionId;
  double _focusSeconds = 0;
  DateTime? _focusResumeAt;
  Session? _finished;
  Timer? _ticker;

  TimerService(this._sessionRepo, this._settings) {
    _phaseTotalSec = _settings.workMinutes * 60;
    _remainingMs = _settings.workMinutes * 60000;
  }

  TimerMode get mode => _mode;
  TimerState get state => _state;
  int get completedCycles => _completedCycles;
  int? get activeProjectId => _activeProjectId;
  int? get lastProjectId => _lastProjectId;
  Session? get finished => _finished;
  bool get hasFinished => _finished != null;

  int get phaseTotalSeconds => _phaseTotalSec;

  int get remainingSeconds {
    if (_state == TimerState.running && _resumeAt != null) {
      final ms = _resumeRemainingMs - DateTime.now().difference(_resumeAt!).inMilliseconds;
      if (ms <= 0) return 0;
      return (ms / 1000).ceil();
    }
    return (_remainingMs / 1000).ceil();
  }

  double get progress {
    if (_phaseTotalSec <= 0) return 0;
    final r = remainingSeconds;
    return (1 - r / _phaseTotalSec).clamp(0.0, 1.0);
  }

  String get formattedTime {
    final r = remainingSeconds;
    final m = (r ~/ 60).toString().padLeft(2, '0');
    final s = (r % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get isRunning => _state == TimerState.running;
  bool get isLongBreak => _mode == TimerMode.longBreak;

  Future<void> startFocus(int projectId) async {
    final id = await _sessionRepo.start(projectId: projectId);
    _activeProjectId = projectId;
    _lastProjectId = projectId;
    _activeSessionId = id;
    _focusSeconds = 0;
    _focusResumeAt = DateTime.now();
    _finished = null;
    _mode = TimerMode.focus;
    _phaseTotalSec = _settings.workMinutes * 60;
    _remainingMs = _phaseTotalSec * 1000;
    _beginRunning();
    notifyListeners();
  }

  void pause() {
    if (_state != TimerState.running) return;
    _accumulateFocus();
    _remainingMs = remainingSeconds * 1000;
    _resumeAt = null;
    _state = TimerState.paused;
    _ticker?.cancel();
    final sid = _activeSessionId;
    if (sid != null) _sessionRepo.pause(id: sid);
    notifyListeners();
  }

  void resume() {
    if (_state != TimerState.paused) return;
    _focusResumeAt = DateTime.now();
    final sid = _activeSessionId;
    if (sid != null) _sessionRepo.resume(id: sid);
    _beginRunning();
    notifyListeners();
  }

  /// Ends the current focus phase. Returns the finished session if the phase
  /// was focus (for review/contributions), or null for a break.
  Future<Session?> completePhase() async {
    _ticker?.cancel();
    _state = TimerState.idle;
    _resumeAt = null;

    if (_mode == TimerMode.focus) {
      _accumulateFocus();
      _completedCycles++;
      final duration = _focusSeconds;
      _focusSeconds = 0;
      final sid = _activeSessionId;
      if (sid != null) {
        await _sessionRepo.complete(id: sid, duration: duration);
        final finished = await _sessionRepo.getById(sid);
        _finished = finished;
      } else {
        _finished = null;
      }
      _activeSessionId = null;
      _activeProjectId = null;
      notifyListeners();
      return _finished;
    }

    // Break finished -> back to focus.
    _finished = null;
    _activeProjectId = _lastProjectId;
    _mode = TimerMode.focus;
    _phaseTotalSec = _settings.workMinutes * 60;
    _remainingMs = _phaseTotalSec * 1000;
    _focusSeconds = 0;
    notifyListeners();
    return null;
  }

  Future<Session?> registerInterrupted() async {
    _ticker?.cancel();
    _state = TimerState.idle;
    _resumeAt = null;
    _accumulateFocus();
    final duration = _focusSeconds;
    _focusSeconds = 0;
    final sid = _activeSessionId;
    Session? finished;
    if (sid != null) {
      await _sessionRepo.endSession(id: sid, duration: duration, status: 'interrupted');
      finished = await _sessionRepo.getById(sid);
    }
    _finished = finished;
    _activeSessionId = null;
    _activeProjectId = null;
    notifyListeners();
    return finished;
  }

  Future<void> discard() async {
    _ticker?.cancel();
    _state = TimerState.idle;
    _resumeAt = null;
    _focusSeconds = 0;
    final sid = _activeSessionId;
    if (sid != null) await _sessionRepo.delete(sid);
    _activeSessionId = null;
    _activeProjectId = null;
    _finished = null;
    notifyListeners();
  }

  void startBreak() {
    _ticker?.cancel();
    final isLong = _completedCycles > 0 &&
        _completedCycles % _settings.cyclesBeforeLongBreak == 0;
    _mode = isLong ? TimerMode.longBreak : TimerMode.shortBreak;
    _phaseTotalSec =
        (_mode == TimerMode.longBreak ? _settings.longBreakMinutes : _settings.breakMinutes) * 60;
    _remainingMs = _phaseTotalSec * 1000;
    _finished = null;
    _beginRunning();
    notifyListeners();
  }

  void skipBreak() {
    _ticker?.cancel();
    _state = TimerState.idle;
    _finished = null;
    _mode = TimerMode.focus;
    _phaseTotalSec = _settings.workMinutes * 60;
    _remainingMs = _phaseTotalSec * 1000;
    _activeProjectId = _lastProjectId;
    notifyListeners();
  }

  void _beginRunning() {
    _resumeRemainingMs = _remainingMs;
    _resumeAt = DateTime.now();
    _state = TimerState.running;
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (remainingSeconds <= 0) {
        completePhase();
      } else {
        notifyListeners();
      }
    });
  }

  void _accumulateFocus() {
    if (_focusResumeAt != null && _mode == TimerMode.focus) {
      _focusSeconds += DateTime.now().difference(_focusResumeAt!).inMilliseconds / 1000.0;
    }
    _focusResumeAt = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
