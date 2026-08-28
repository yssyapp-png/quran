import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/reciter.dart';
import '../core/constants/quran_index.dart';
import 'quran_text_service.dart';

enum AudioPlaybackState { idle, loading, playing, paused, error }

enum _PlaybackMode { page, ayah, fullSurah }

class QuranAudioService extends ChangeNotifier {
  QuranAudioService({this.onPageStarted, QuranTextService? quranTextService})
    : _quranTextService = quranTextService ?? QuranTextService() {
    _subscription = _player.playerStateStream.listen(_handlePlayerState);
  }

  static const int lastMushafPage = 604;

  final ValueChanged<int>? onPageStarted;
  final AudioPlayer _player = AudioPlayer();
  final QuranTextService _quranTextService;
  StreamSubscription<PlayerState>? _subscription;

  AudioPlaybackState _state = AudioPlaybackState.idle;
  int? _playingPage;
  int? _playingSurahNumber;
  int? _playingAyahNumber;
  _PlaybackMode? _playbackMode;
  Reciter _reciter = Reciters.defaultReciter;

  AudioPlaybackState get state => _state;
  int? get playingPage => _playingPage;
  int? get playingSurahNumber => _playingSurahNumber;
  int? get playingAyahNumber => _playingAyahNumber;
  bool get isPlaying => _state == AudioPlaybackState.playing;
  bool get isLoading => _state == AudioPlaybackState.loading;
  Reciter get reciter => _reciter;
  String get reciterName => _reciter.nameAr;
  String get playbackDescription => _reciter.playsFullSurah
      ? 'السورة كاملة · 128kbps'
      : _playbackMode == _PlaybackMode.ayah && _playingAyahNumber != null
      ? 'الآية $_playingSurahNumber:$_playingAyahNumber · 128kbps'
      : 'آيات الصفحة · 128kbps';

  /// Files for this reciter are one file per surah, so they cannot be
  /// accurately positioned at an individual ayah without verified timings.
  bool get supportsAyahSelection => !_reciter.playsFullSurah;

  Future<void> selectReciter(Reciter reciter) async {
    if (_reciter.id == reciter.id) return;
    await stop();
    _reciter = reciter;
    notifyListeners();
  }

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
    _playingAyahNumber = null;
    _playbackMode = _PlaybackMode.page;
    _setState(AudioPlaybackState.loading);
    final verses = await _quranTextService.versesByPage(pageNumber);
    if (verses.isEmpty) {
      throw const FormatException('لا توجد آيات في صفحة المصحف');
    }
    if (_reciter.playsFullSurah) {
      final surahNumber = int.tryParse(verses.first.verseKey.split(':').first);
      if (surahNumber == null) {
        throw const FormatException('تعذر تحديد السورة للتلاوة');
      }
      await _playFullSurah(surahNumber, pageNumber);
    } else {
      _playingSurahNumber = null;
      final sources = verses
          .map((verse) {
            final parts = verse.verseKey.split(':');
            final surahNumber = int.tryParse(parts.first);
            final ayahNumber = parts.length == 2
                ? int.tryParse(parts.last)
                : null;
            if (surahNumber == null || ayahNumber == null) {
              throw const FormatException('تعذر تحديد الآية للتلاوة');
            }
            return AudioSource.uri(
              Uri.parse(_reciter.audioUrl(surahNumber, ayahNumber)),
            );
          })
          .toList(growable: false);
      await _player.setAudioSource(ConcatenatingAudioSource(children: sources));
      await _player.play();
      _setState(AudioPlaybackState.playing);
      onPageStarted?.call(pageNumber);
    }
  }

  Future<void> _playFullSurah(int surahNumber, int pageNumber) async {
    _playingPage = pageNumber;
    _playingSurahNumber = surahNumber;
    _playingAyahNumber = null;
    _playbackMode = _PlaybackMode.fullSurah;
    _setState(AudioPlaybackState.loading);
    await _player.setUrl(_reciter.audioUrl(surahNumber, 1));
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

  /// Starts at the exact requested ayah and continues through the remaining
  /// ayat, then proceeds to the next surah. This is only used with reciters
  /// whose source provides one audio file per ayah.
  Future<void> playAyah(int surahNumber, int ayahNumber) async {
    if (!supportsAyahSelection) {
      throw UnsupportedError('القارئ المختار لا يدعم الانتقال الدقيق بين الآيات');
    }
    if (surahNumber < 1 || surahNumber > QuranIndex.surahs.length) {
      throw RangeError.range(surahNumber, 1, QuranIndex.surahs.length);
    }
    final surah = QuranIndex.surahs[surahNumber - 1];
    if (ayahNumber < 1 || ayahNumber > surah.verses) {
      throw RangeError.range(ayahNumber, 1, surah.verses);
    }

    _playingPage = null;
    _playingSurahNumber = surahNumber;
    _playingAyahNumber = ayahNumber;
    _playbackMode = _PlaybackMode.ayah;
    _setState(AudioPlaybackState.loading);
    await _player.setUrl(_reciter.audioUrl(surahNumber, ayahNumber));
    await _player.play();
    _setState(AudioPlaybackState.playing);
  }

  Future<void> stop() async {
    await _player.stop();
    _playingPage = null;
    _playingSurahNumber = null;
    _playingAyahNumber = null;
    _playbackMode = null;
    _setState(AudioPlaybackState.idle);
  }

  void _handlePlayerState(PlayerState state) {
    if (state.processingState != ProcessingState.completed) return;
    if (_playbackMode == _PlaybackMode.ayah) {
      final surahNumber = _playingSurahNumber;
      final ayahNumber = _playingAyahNumber;
      if (surahNumber != null && ayahNumber != null) {
        final surah = QuranIndex.surahs[surahNumber - 1];
        if (ayahNumber < surah.verses) {
          unawaited(_continueWithAyah(surahNumber, ayahNumber + 1));
          return;
        }
        if (surahNumber < QuranIndex.surahs.length) {
          unawaited(_continueWithAyah(surahNumber + 1, 1));
          return;
        }
      }
    } else if (_reciter.playsFullSurah) {
      final completedSurah = _playingSurahNumber;
      if (completedSurah != null && completedSurah < 114) {
        final nextSurah = QuranIndex.surahs[completedSurah];
        unawaited(_continueWithFullSurah(completedSurah + 1, nextSurah.page));
        return;
      }
    } else {
      final completedPage = _playingPage;
      if (completedPage != null && completedPage < lastMushafPage) {
        unawaited(_continueWithPage(completedPage + 1));
        return;
      }
    }
    _playingPage = null;
    _playingSurahNumber = null;
    _playingAyahNumber = null;
    _playbackMode = null;
    _setState(AudioPlaybackState.idle);
  }

  Future<void> _continueWithFullSurah(int surahNumber, int pageNumber) async {
    try {
      await _playFullSurah(surahNumber, pageNumber);
    } catch (_) {
      _playingPage = null;
      _playingSurahNumber = null;
      _setState(AudioPlaybackState.error);
    }
  }

  Future<void> _continueWithPage(int pageNumber) async {
    try {
      await playPage(pageNumber);
    } catch (_) {
      _playingPage = null;
      _setState(AudioPlaybackState.error);
    }
  }

  Future<void> _continueWithAyah(int surahNumber, int ayahNumber) async {
    try {
      await playAyah(surahNumber, ayahNumber);
    } catch (_) {
      _playingPage = null;
      _playingSurahNumber = null;
      _playingAyahNumber = null;
      _playbackMode = null;
      _setState(AudioPlaybackState.error);
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
    _quranTextService.close();
    super.dispose();
  }
}
