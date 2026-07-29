import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/local_ayah.dart';
import '../models/reciter.dart';
import '../services/quran_local_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

/// استماع متواصل: تشغيل سورة كاملة آية بآية دون الحاجة لفتح صفحات المصحف،
/// مفيد للاستماع في الخلفية أثناء التنقل مثلًا.
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  final QuranLocalService _service = QuranLocalService();
  final SettingsService _settingsService = SettingsService();
  final AudioPlayer _player = AudioPlayer();
  Reciter _reciter = Reciters.defaultReciter;
  late Future<List<LocalSurahInfo>> _surahsFuture;

  LocalSurahInfo? _playingSurah;
  List<LocalAyah> _ayahs = [];
  int _index = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _surahsFuture = _service.getSurahList();
    _settingsService.getSelectedReciter().then((r) {
      if (mounted) setState(() => _reciter = r);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playSurah(LocalSurahInfo surah) async {
    final ayahs = await _service.getSurahAyahs(surah.number);
    if (!mounted) return;
    setState(() {
      _playingSurah = surah;
      _ayahs = ayahs;
      _index = 0;
      _isPlaying = true;
    });
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_index >= _ayahs.length) {
      setState(() {
        _isPlaying = false;
        _playingSurah = null;
      });
      return;
    }
    final ayah = _ayahs[_index];
    await _player.setUrl(_reciter.audioUrl(ayah.suraNo, ayah.ayaNo));
    _player.play();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted && _isPlaying) {
        setState(() => _index++);
        _playCurrent();
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else if (_playingSurah != null) {
      await _player.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() {
      _isPlaying = false;
      _playingSurah = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استماع')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<LocalSurahInfo>>(
              future: _surahsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.gold));
                }
                final surahs = snapshot.data!;
                return ListView.builder(
                  itemCount: surahs.length,
                  itemBuilder: (context, i) {
                    final s = surahs[i];
                    final playing = _playingSurah?.number == s.number;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: playing ? AppColors.gold : AppColors.inkGreen,
                        foregroundColor: playing ? AppColors.inkGreen : AppColors.cream,
                        child: Text('${s.number}'),
                      ),
                      title: Text(s.nameAr),
                      trailing: Icon(playing && _isPlaying ? Icons.pause_circle : Icons.play_circle_outline),
                      onTap: () => _playSurah(s),
                    );
                  },
                );
              },
            ),
          ),
          if (_playingSurah != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.inkGreen,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_playingSurah!.nameAr} — آية ${_index + 1} من ${_ayahs.length} — ${_reciter.nameAr}',
                      style: const TextStyle(color: AppColors.cream),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: AppColors.gold),
                    onPressed: _togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, color: AppColors.gold),
                    onPressed: _stop,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
