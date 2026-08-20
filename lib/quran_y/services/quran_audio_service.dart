import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

enum AudioPlaybackState { idle, loading, playing, paused, error }

class QuranAudioService extends ChangeNotifier {
  QuranAudioService({this.onPageStarted}) {
    _subscription = _player.playerStateStream.listen(_handlePlayerState);
  }

  static const String reciterName = 'سعد الغامدي';
  static const int lastMushafPage = 604;

  final ValueChanged<int>? onPageStarted;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _subscription;

  AudioPlaybackState _state = AudioPlaybackState.idle;
  int? _playingPage;

  AudioPlaybackState get state => _state;
  int? get playingPage => _playingPage;
  bool get isPlaying => _state == AudioPlaybackState.playing;
  bool get isLoading => _state == AudioPlaybackState.loading;

  Future<void> togglePage(int pageNumber) async {
    try {
      if (_playingPage == pageNumber && isPlaying) {
        await pause();
      } else if (_playingPage == pageNumber &&
          _state == AudioPlaybackState.paused) {
        await resume();
      } else {
        await playPage(pageNumber);
      }
    } catch (_) {
      _setState(AudioPlaybackState.error);
    }
  }

  Future<void> playPage(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > lastMushafPage) return;
    _playingPage = pageNumber;
    _setState(AudioPlaybackState.loading);
    final page = pageNumber.toString().padLeft(3, '0');
    final url =
        'https://everyayah.com/data/Ghamadi_40kbps/PageMp3s/Page$page.mp3';
    await _player.setUrl(url);
    await _player.play();
    _setState(AudioPlaybackState.playing);
    onPageStarted?.call(pageNumber);
  }

  Future<void> pause() async {
    await _player.pause();
    _setState(AudioPlaybackState.paused);
  }

  Future<void> resume() async {
    await _player.play();
    _setState(AudioPlaybackState.playing);
  }

  Future<void> stop() async {
    await _player.stop();
    _playingPage = null;
    _setState(AudioPlaybackState.idle);
  }

  void _handlePlayerState(PlayerState state) {
    if (state.processingState != ProcessingState.completed) return;
    final completedPage = _playingPage;
    if (completedPage != null && completedPage < lastMushafPage) {
      unawaited(playPage(completedPage + 1));
    } else {
      _playingPage = null;
      _setState(AudioPlaybackState.idle);
    }
  }

  void _setState(AudioPlaybackState value) {
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
