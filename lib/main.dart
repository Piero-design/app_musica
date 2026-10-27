import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const AppleMusicApp());
}

// ============================================================================
// 1. MODELOS DE DATOS (Data Models)
// ============================================================================

enum PlaybackMode { standard, snippetMix, aiRadio }
enum RepeatMode { off, all, one }

class SongSegment {
  final String name;
  final int startSeconds;
  final int endSeconds;
  final bool isViralHighlight;

  const SongSegment({
    required this.name,
    required this.startSeconds,
    required this.endSeconds,
    this.isViralHighlight = false,
  });
}

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String duration;
  final int durationSeconds;
  final Color coverColor;
  final Color secondaryColor;
  final IconData coverIcon;
  final String genre;
  final int bpm;
  final List<SongSegment> segments;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.durationSeconds,
    required this.coverColor,
    required this.secondaryColor,
    required this.coverIcon,
    required this.genre,
    required this.bpm,
    required this.segments,
  });
}

class Artist {
  final String id;
  final String name;

  const Artist({required this.id, required this.name});
}

class Album {
  final String id;
  final String title;
  final String artistName;

  const Album({
    required this.id,
    required this.title,
    required this.artistName,
  });
}

class GenreTag {
  final String id;
  final String name;

  const GenreTag({required this.id, required this.name});
}

class MixItem {
  final Song song;
  SongSegment segment;
  int loopCount; // Bucles a repetir (ej: 3 veces)
  int currentLoop; // Bucle actual

  MixItem({
    required this.song,
    required this.segment,
    this.loopCount = 3,
    this.currentLoop = 1,
  });
}

class RadioStation {
  final String id;
  final String name;
  final String genre;
  final String description;
  final IconData icon;
  final Color color1;
  final Color color2;
  final List<String> songIds;
  final String hostTopic;

  const RadioStation({
    required this.id,
    required this.name,
    required this.genre,
    required this.description,
    required this.icon,
    required this.color1,
    required this.color2,
    required this.songIds,
    required this.hostTopic,
  });
}

class AiHostCapsule {
  final String hostName;
  final String topicBadge;
  final String message;
  final int durationSeconds;

  const AiHostCapsule({
    required this.hostName,
    required this.topicBadge,
    required this.message,
    required this.durationSeconds,
  });
}

// ============================================================================
// 2. PATRÓN MEDIATOR: EVENTOS Y DEFINICIÓN DE LA INTERFAZ
// ============================================================================

enum PlaybackEvent {
  playPauseToggled,
  nextRequested,
  previousRequested,
  songSelected,
  mixSnippetSelected,
  radioStationSelected,
  progressSeeked,
  volumeChanged,
  favoriteToggled,
  triggerHostSpeechManually,
  dismissHostSpeech,
  toggleAiHostActive,
  changeHostInterest,
  changeLoopCount,
  changeSnippetSegment,
  addSongToMix,
  toggleShuffle,
  cycleRepeatMode,
}

abstract class IPlaybackMediator {
  void notify(PlaybackEvent event, {dynamic payload});
}

// ============================================================================
// 3. MANEJADORES ESPECIALIZADOS (Evitan el "God Object")
// ============================================================================

/// Manejador de la Cola y Biblioteca de Canciones (Single Responsibility)
class QueueHandler {
  final List<Song> library;
  final List<Song> queue;
  final Set<String> favoriteSongIds = {'1', '2'};
  final Random _random = Random();
  bool isShuffleEnabled = false;
  RepeatMode repeatMode = RepeatMode.off;
  int _currentQueueIndex = 0;
  late Song currentSong;

  QueueHandler({required this.library}) : queue = List<Song>.from(library) {
    currentSong = queue.first;
  }

  List<Artist> get artists {
    final seen = <String>{};
    return library.where((song) => seen.add(song.artist)).map((song) {
      return Artist(id: 'artist_${song.artist}', name: song.artist);
    }).toList(growable: false);
  }

  List<Album> get albums {
    final seen = <String>{};
    return library.where((song) => seen.add(song.album)).map((song) {
      return Album(
        id: 'album_${song.album}',
        title: song.album,
        artistName: song.artist,
      );
    }).toList(growable: false);
  }

  List<GenreTag> get genres {
    final seen = <String>{};
    return library.where((song) => seen.add(song.genre)).map((song) {
      return GenreTag(id: 'genre_${song.genre}', name: song.genre);
    }).toList(growable: false);
  }

  void selectSong(Song song) {
    currentSong = song;
    final queueIndex = queue.indexWhere((s) => s.id == song.id);
    if (queueIndex != -1) {
      _currentQueueIndex = queueIndex;
    }
  }

  Song? getNextSong() {
    if (queue.isEmpty) return null;
    if (repeatMode == RepeatMode.one) return currentSong;

    if (isShuffleEnabled && queue.length > 1) {
      var nextIndex = _currentQueueIndex;
      while (nextIndex == _currentQueueIndex) {
        nextIndex = _random.nextInt(queue.length);
      }
      _currentQueueIndex = nextIndex;
      currentSong = queue[_currentQueueIndex];
      return currentSong;
    }

    final isLastSong = _currentQueueIndex >= queue.length - 1;
    if (isLastSong) {
      if (repeatMode == RepeatMode.all) {
        _currentQueueIndex = 0;
        currentSong = queue[_currentQueueIndex];
        return currentSong;
      }
      return null;
    }

    _currentQueueIndex++;
    currentSong = queue[_currentQueueIndex];
    return currentSong;
  }

  Song getPreviousSong() {
    if (queue.isEmpty || repeatMode == RepeatMode.one) return currentSong;

    if (isShuffleEnabled && queue.length > 1) {
      var previousIndex = _currentQueueIndex;
      while (previousIndex == _currentQueueIndex) {
        previousIndex = _random.nextInt(queue.length);
      }
      _currentQueueIndex = previousIndex;
      currentSong = queue[_currentQueueIndex];
      return currentSong;
    }

    if (_currentQueueIndex == 0) {
      if (repeatMode == RepeatMode.all) {
        _currentQueueIndex = queue.length - 1;
      }
    } else {
      _currentQueueIndex--;
    }

    currentSong = queue[_currentQueueIndex];
    return currentSong;
  }

  void toggleFavorite(String songId) {
    if (favoriteSongIds.contains(songId)) {
      favoriteSongIds.remove(songId);
    } else {
      favoriteSongIds.add(songId);
    }
  }

  void toggleShuffle() {
    isShuffleEnabled = !isShuffleEnabled;
  }

  void cycleRepeatMode() {
    repeatMode = switch (repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
  }
}

/// Manejador de Fragmentos, Bucles y Beatmatch (DJ Mix Studio)
class SnippetLoopHandler {
  final List<MixItem> playlist;
  int currentMixIndex = 0;

  SnippetLoopHandler({required this.playlist});

  MixItem get currentItem => playlist[currentMixIndex];

  void selectSnippet(int index) {
    currentMixIndex = index;
    playlist[currentMixIndex].currentLoop = 1;
  }

  /// Retorna TRUE si debe repetir el bucle en el mismo fragmento,
  /// o FALSE si culminó los bucles (ej. 3/3) y debe avanzar a la siguiente pista.
  bool processTickAndCheckLoop(double currentSeconds) {
    final item = currentItem;
    if (currentSeconds >= item.segment.endSeconds) {
      if (item.currentLoop < item.loopCount) {
        item.currentLoop++;
        return true; // Repetir bucle
      } else {
        item.currentLoop = 1; // Reiniciar para próxima ocasión
        return false; // Pasar a siguiente pista
      }
    }
    return true;
  }

  void advanceToNext() {
    currentMixIndex = (currentMixIndex + 1) % playlist.length;
    playlist[currentMixIndex].currentLoop = 1;
  }

  void advanceToPrevious() {
    currentMixIndex = (currentMixIndex - 1 + playlist.length) % playlist.length;
    playlist[currentMixIndex].currentLoop = 1;
  }

  void changeLoopCount(int index, int count) {
    if (index >= 0 && index < playlist.length) {
      playlist[index].loopCount = count;
    }
  }

  void changeSegment(int index, SongSegment segment) {
    if (index >= 0 && index < playlist.length) {
      playlist[index].segment = segment;
    }
  }

  void addSong(Song song) {
    playlist.add(
      MixItem(
        song: song,
        segment: song.segments.first,
        loopCount: 3,
      ),
    );
  }
}

/// Manejador del Locutor Virtual IA y Emisoras de Radio
class AiRadioHostHandler {
  final List<RadioStation> stations;
  final List<AiHostCapsule> capsules;
  RadioStation? activeStation;
  bool isAiHostActive = true;
  String selectedInterest = 'Ingeniería de Sistemas y Tech';
  bool isHostSpeaking = false;
  AiHostCapsule? activeCapsule;
  Timer? _speechTimer;

  AiRadioHostHandler({required this.stations, required this.capsules});

  void dispose() {
    _speechTimer?.cancel();
  }

  void selectStation(RadioStation station) {
    activeStation = station;
  }

  Song getNextRadioSong(List<Song> library, Song currentSong) {
    if (activeStation != null) {
      final validSongs = library.where((s) => activeStation!.songIds.contains(s.id)).toList();
      if (validSongs.isNotEmpty) {
        final currentIdx = validSongs.indexWhere((s) => s.id == currentSong.id);
        final nextIdx = (currentIdx + 1) % validSongs.length;
        return validSongs[nextIdx];
      }
    }
    final nextIndex = (library.indexOf(currentSong) + 1) % library.length;
    return library[nextIndex];
  }

  void triggerSpeech({required VoidCallback onSpeechFinished}) {
    _speechTimer?.cancel();
    isHostSpeaking = true;
    activeCapsule = (capsules.toList()..shuffle()).first;

    _speechTimer = Timer(Duration(seconds: activeCapsule!.durationSeconds), () {
      isHostSpeaking = false;
      activeCapsule = null;
      onSpeechFinished();
    });
  }

  void dismissSpeech() {
    _speechTimer?.cancel();
    isHostSpeaking = false;
    activeCapsule = null;
  }
}

// ============================================================================
// 4. MEDIADOR CONCRETO (Coordina los manejadores sin acoplarlos)
// ============================================================================

class MusicPlaybackMediator extends ChangeNotifier implements IPlaybackMediator {
  final QueueHandler queueHandler;
  final SnippetLoopHandler snippetHandler;
  final AiRadioHostHandler radioHandler;

  PlaybackMode _mode = PlaybackMode.standard;
  bool _isPlaying = false;
  double _currentProgressSeconds = 0.0;
  double _volume = 0.8;
  Timer? _playbackTicker;

  MusicPlaybackMediator({
    required this.queueHandler,
    required this.snippetHandler,
    required this.radioHandler,
  }) {
    _startTicker();
  }

  // Getters para la interfaz de usuario
  PlaybackMode get mode => _mode;
  bool get isPlaying => _isPlaying;
  double get currentProgressSeconds => _currentProgressSeconds;
  double get volume => _volume;
  Song get currentSong => _mode == PlaybackMode.snippetMix
      ? snippetHandler.currentItem.song
      : queueHandler.currentSong;
  bool get isShuffleEnabled => queueHandler.isShuffleEnabled;
  RepeatMode get repeatMode => queueHandler.repeatMode;

  void _startTicker() {
    _playbackTicker = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isPlaying || radioHandler.isHostSpeaking) return;

      if (_mode == PlaybackMode.snippetMix) {
        _currentProgressSeconds += 0.5;
        final shouldStay = snippetHandler.processTickAndCheckLoop(_currentProgressSeconds);
        if (!shouldStay) {
          // Bucles concluidos: el mediador coordina el salto al siguiente snippet
          snippetHandler.advanceToNext();
          _currentProgressSeconds = snippetHandler.currentItem.segment.startSeconds.toDouble();
        } else if (_currentProgressSeconds >= snippetHandler.currentItem.segment.endSeconds) {
          // Bucle repetido: volver al inicio del segmento
          _currentProgressSeconds = snippetHandler.currentItem.segment.startSeconds.toDouble();
        }
      } else {
        _currentProgressSeconds += 0.5;
        if (_currentProgressSeconds >= currentSong.durationSeconds) {
          notify(PlaybackEvent.nextRequested);
        }
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _playbackTicker?.cancel();
    radioHandler.dispose();
    super.dispose();
  }

  /// Método centralizado del Patrón Mediator
  @override
  void notify(PlaybackEvent event, {dynamic payload}) {
    switch (event) {
      case PlaybackEvent.playPauseToggled:
        _isPlaying = !_isPlaying;
        break;

      case PlaybackEvent.songSelected:
        final song = payload as Song;
        queueHandler.selectSong(song);
        _mode = PlaybackMode.standard;
        _currentProgressSeconds = 0.0;
        _isPlaying = true;
        radioHandler.dismissSpeech();
        break;

      case PlaybackEvent.mixSnippetSelected:
        final index = payload as int;
        snippetHandler.selectSnippet(index);
        _mode = PlaybackMode.snippetMix;
        _currentProgressSeconds = snippetHandler.currentItem.segment.startSeconds.toDouble();
        _isPlaying = true;
        radioHandler.dismissSpeech();
        break;

      case PlaybackEvent.radioStationSelected:
        final station = payload as RadioStation;
        radioHandler.selectStation(station);
        final firstSong = queueHandler.library.firstWhere(
          (s) => station.songIds.contains(s.id),
          orElse: () => queueHandler.library.first,
        );
        queueHandler.selectSong(firstSong);
        _mode = PlaybackMode.aiRadio;
        _currentProgressSeconds = 0.0;
        _isPlaying = true;

        if (radioHandler.isAiHostActive) {
          radioHandler.triggerSpeech(onSpeechFinished: () => notifyListeners());
        }
        break;

      case PlaybackEvent.nextRequested:
        if (_mode == PlaybackMode.snippetMix) {
          snippetHandler.advanceToNext();
          _currentProgressSeconds = snippetHandler.currentItem.segment.startSeconds.toDouble();
        } else if (_mode == PlaybackMode.aiRadio && radioHandler.isAiHostActive) {
          radioHandler.triggerSpeech(onSpeechFinished: () {
            final nextSong = radioHandler.getNextRadioSong(queueHandler.library, currentSong);
            queueHandler.selectSong(nextSong);
            _currentProgressSeconds = 0.0;
            _isPlaying = true;
            notifyListeners();
          });
        } else {
          final nextSong = queueHandler.getNextSong();
          if (nextSong == null) {
            _isPlaying = false;
            _currentProgressSeconds = currentSong.durationSeconds.toDouble();
          } else {
            _currentProgressSeconds = 0.0;
          }
        }
        break;

      case PlaybackEvent.previousRequested:
        if (_mode == PlaybackMode.snippetMix) {
          snippetHandler.advanceToPrevious();
          _currentProgressSeconds = snippetHandler.currentItem.segment.startSeconds.toDouble();
        } else {
          queueHandler.getPreviousSong();
          _currentProgressSeconds = 0.0;
        }
        break;

      case PlaybackEvent.progressSeeked:
        _currentProgressSeconds = (payload as double);
        break;

      case PlaybackEvent.volumeChanged:
        _volume = (payload as double);
        break;

      case PlaybackEvent.favoriteToggled:
        queueHandler.toggleFavorite(payload as String);
        break;

      case PlaybackEvent.triggerHostSpeechManually:
        radioHandler.triggerSpeech(onSpeechFinished: () => notifyListeners());
        break;

      case PlaybackEvent.dismissHostSpeech:
        radioHandler.dismissSpeech();
        break;

      case PlaybackEvent.toggleAiHostActive:
        radioHandler.isAiHostActive = payload as bool;
        break;

      case PlaybackEvent.changeHostInterest:
        radioHandler.selectedInterest = payload as String;
        break;

      case PlaybackEvent.changeLoopCount:
        final data = payload as Map<String, int>;
        snippetHandler.changeLoopCount(data['index']!, data['count']!);
        break;

      case PlaybackEvent.changeSnippetSegment:
        final data = payload as Map<String, dynamic>;
        snippetHandler.changeSegment(data['index'] as int, data['segment'] as SongSegment);
        if (_mode == PlaybackMode.snippetMix && snippetHandler.currentMixIndex == data['index']) {
          _currentProgressSeconds = (data['segment'] as SongSegment).startSeconds.toDouble();
        }
        break;

      case PlaybackEvent.addSongToMix:
        snippetHandler.addSong(payload as Song);
        break;

      case PlaybackEvent.toggleShuffle:
        queueHandler.toggleShuffle();
        break;

      case PlaybackEvent.cycleRepeatMode:
        queueHandler.cycleRepeatMode();
        break;
    }

    notifyListeners();
  }
}

// ============================================================================
// 5. APLICACIÓN PRINCIPAL Y CAPA DE PRESENTACIÓN (UI)
// ============================================================================

class AppleMusicApp extends StatelessWidget {
  const AppleMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple Music Mediator',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFA2D48),
          secondary: Color(0xFFFF375F),
          surface: Color(0xFF1C1C1E),
        ),
        useMaterial3: true,
      ),
      home: const AppleMusicMainScreen(),
    );
  }
}

class AppleMusicMainScreen extends StatefulWidget {
  const AppleMusicMainScreen({super.key});

  @override
  State<AppleMusicMainScreen> createState() => _AppleMusicMainScreenState();
}

class _PlaylistSearchStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String searchQuery;
  final String selectedGenreFilter;
  final int totalCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onGenreSelected;

  const _PlaylistSearchStickyHeaderDelegate({
    required this.topPadding,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchQuery,
    required this.selectedGenreFilter,
    required this.totalCount,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onGenreSelected,
  });

  static const double _titleHeight = 42.0;
  static const double _controlsHeight = 80.0;

  @override
  double get maxExtent => topPadding + _titleHeight + _controlsHeight;

  @override
  double get minExtent => topPadding + _controlsHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final titleProgress = (1.0 - (shrinkOffset / _titleHeight)).clamp(0.0, 1.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.black.withValues(alpha: 0.90),
          padding: EdgeInsets.only(
            top: topPadding + 4,
            left: 20,
            right: 20,
            bottom: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título "Escuchar" + Avatar (se comprime suavemente al scrollear)
              if (titleProgress > 0.05)
                ClipRect(
                  child: SizedBox(
                    height: _titleHeight * titleProgress,
                    child: Opacity(
                      opacity: titleProgress,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Escuchar',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: Colors.white,
                            ),
                          ),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF2C2C2E),
                            child: const Icon(Icons.person_rounded, color: Colors.white70, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Barra de búsqueda específica de esta playlist (siempre debajo del notch y status bar)
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: searchQuery.isNotEmpty
                        ? const Color(0xFFFA2D48).withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, color: Color(0xFFFA2D48), size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Filtrar en esta playlist ($totalCount temas)...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: onSearchChanged,
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: onClearSearch,
                        child: const Icon(Icons.cancel_rounded, color: Colors.white54, size: 18),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Chips de género y favoritos para filtrado instantáneo
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    'Todas',
                    'Favoritas ⭐',
                    'Focus Tech',
                    'Electrónica',
                    'Synthwave',
                    'Pop',
                    'Rock',
                    'Urbano',
                    'Hip-Hop',
                    'BPM > 120',
                  ].map((tag) {
                    final isSelected = selectedGenreFilter == tag;
                    return GestureDetector(
                      onTap: () => onGenreSelected(tag),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFA2D48) : const Color(0xFF24242C),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PlaylistSearchStickyHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.searchQuery != searchQuery ||
        oldDelegate.selectedGenreFilter != selectedGenreFilter ||
        oldDelegate.totalCount != totalCount;
  }
}

class _AppleMusicMainScreenState extends State<AppleMusicMainScreen> {
  late final MusicPlaybackMediator _mediator;
  final ScrollController _listenScrollController = ScrollController();
  final TextEditingController _inPlaylistSearchController = TextEditingController();
  final TextEditingController _searchTabController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _selectedTabIndex = 0;
  String _inPlaylistSearchQuery = '';
  String _searchTabQuery = '';
  String _searchTabFilter = 'Todas';
  String _selectedGenreFilter = 'Todas';
  bool _showScrollToTop = false;

  // Catálogo completo de 120 canciones para probar listas largas y filtros en tiempo real
  static List<Song> _generateCatalog() {
    final rawSongs = [
      // 1-15: Synthwave / Electrónica Hits
      ('Midnight City', 'M83', "Hurry Up, We're Dreaming", 243, 'Electrónica', 105, const Color(0xFF5E35B1), const Color(0xFFD81B60), Icons.nightlife_rounded),
      ('Blinding Lights', 'The Weeknd', 'After Hours', 200, 'Synthwave', 171, const Color(0xFFE53935), const Color(0xFFFB8C00), Icons.flash_on_rounded),
      ('Starboy', 'The Weeknd ft. Daft Punk', 'Starboy', 230, 'Electro Pop', 186, const Color(0xFF00ACC1), const Color(0xFF1E88E5), Icons.star_rounded),
      ('Save Your Tears', 'The Weeknd', 'After Hours', 215, 'Synthpop', 118, const Color(0xFF00897B), const Color(0xFF43A047), Icons.water_drop_rounded),
      ('Resonance', 'HOME', 'Odyssey', 212, 'Synthwave', 170, const Color(0xFF673AB7), const Color(0xFF00E5FF), Icons.grain_rounded),
      ('Nightcall', 'Kavinsky', 'OutRun', 259, 'Synthwave', 90, const Color(0xFFE91E63), const Color(0xFF311B92), Icons.directions_car_rounded),
      ('After Dark', 'Mr.Kitty', 'Time', 259, 'Synthwave', 140, const Color(0xFF3F51B5), const Color(0xFF880E4F), Icons.nightlight_round),
      ('Memory Reboot', 'VOJ & Narvent', 'Memory Reboot', 104, 'Synthwave', 130, const Color(0xFF00E676), const Color(0xFF00B0FF), Icons.memory_rounded),
      ('Tech Noir', 'GUNSHIP', 'GUNSHIP', 297, 'Synthwave', 96, const Color(0xFFFF1744), const Color(0xFF651FFF), Icons.movie_filter_rounded),
      ('Days of Thunder', 'The Midnight', 'Days of Thunder', 329, 'Synthwave', 100, const Color(0xFFFF6D00), const Color(0xFFFFAB00), Icons.thunderstorm_rounded),
      ('Sunset', 'The Midnight', 'Endless Summer', 326, 'Synthwave', 114, const Color(0xFFFF4081), const Color(0xFF7C4DFF), Icons.wb_twilight_rounded),
      ('Turbo Killer', 'Carpenter Brut', 'Trilogy', 208, 'Synthwave', 135, const Color(0xFFD50000), const Color(0xFF212121), Icons.local_fire_department_rounded),
      ('Innerbloom', 'Rüfüs Du Sol', 'Bloom', 578, 'Electrónica', 121, const Color(0xFF5C6BC0), const Color(0xFF283593), Icons.blur_on_rounded),
      ('Titanium', 'David Guetta ft. Sia', 'Nothing but the Beat', 245, 'Electrónica', 126, const Color(0xFF78909C), const Color(0xFF37474F), Icons.shield_rounded),
      ('Wake Me Up', 'Avicii', 'True', 247, 'Electrónica', 124, const Color(0xFFFFA726), const Color(0xFF8D6E63), Icons.wb_sunny_rounded),

      // 16-30: Daft Punk & French House / Dance
      ('One More Time', 'Daft Punk', 'Discovery', 320, 'Electrónica', 123, const Color(0xFFFF9800), const Color(0xFFE91E63), Icons.album_rounded),
      ('Get Lucky', 'Daft Punk ft. Pharrell', 'Random Access Memories', 248, 'Funk / Disco', 116, const Color(0xFFFFD54F), const Color(0xFFFF7043), Icons.music_note_rounded),
      ('Harder Better Faster Stronger', 'Daft Punk', 'Discovery', 224, 'Electrónica', 123, const Color(0xFF2196F3), const Color(0xFF00E676), Icons.speed_rounded),
      ('Around The World', 'Daft Punk', 'Homework', 429, 'Electrónica', 121, const Color(0xFF673AB7), const Color(0xFFE91E63), Icons.public_rounded),
      ('Instant Crush', 'Daft Punk ft. Julian Casablancas', 'Random Access Memories', 337, 'Synthpop', 110, const Color(0xFF00ACC1), const Color(0xFF5E35B1), Icons.favorite_rounded),
      ('Da Funk', 'Daft Punk', 'Homework', 328, 'Electrónica', 111, const Color(0xFFFF5722), const Color(0xFF795548), Icons.headphones_rounded),
      ('Digital Love', 'Daft Punk', 'Discovery', 298, 'Electrónica', 125, const Color(0xFFE91E63), const Color(0xFF9C27B0), Icons.favorite_border_rounded),
      ('Aerodynamic', 'Daft Punk', 'Discovery', 212, 'Electrónica', 123, const Color(0xFF00BCD4), const Color(0xFF009688), Icons.electric_bolt_rounded),
      ('Veridis Quo', 'Daft Punk', 'Discovery', 345, 'Electrónica', 107, const Color(0xFF3F51B5), const Color(0xFF1A237E), Icons.nature_rounded),
      ('Feel So Close', 'Calvin Harris', '18 Months', 206, 'Electrónica', 128, const Color(0xFF29B6F6), const Color(0xFF0288D1), Icons.speaker_rounded),
      ('Summer', 'Calvin Harris', 'Motion', 222, 'Electrónica', 128, const Color(0xFFFF7043), const Color(0xFFFFCA28), Icons.beach_access_rounded),
      ('Levels', 'Avicii', 'Levels', 198, 'Electrónica', 126, const Color(0xFF42A5F5), const Color(0xFF7E57C2), Icons.equalizer_rounded),
      ('The Nights', 'Avicii', 'The Days / The Nights', 176, 'Electrónica', 126, const Color(0xFFFFA000), const Color(0xFFFF6F00), Icons.brightness_3_rounded),
      ('Losing It', 'FISHER', 'Losing It', 248, 'Tech House', 125, const Color(0xFFFF1744), const Color(0xFFD500F9), Icons.bolt_rounded),
      ('Rumble', 'Skrillex & Fred again..', 'Quest For Fire', 146, 'UK Garage', 140, const Color(0xFF263238), const Color(0xFFFF5252), Icons.sports_mma_rounded),

      // 31-45: Pop & Modern Charts
      ('As It Was', 'Harry Styles', "Harry's House", 167, 'Indie Pop', 174, const Color(0xFFF4511E), const Color(0xFFFFB300), Icons.home_rounded),
      ('Watermelon Sugar', 'Harry Styles', 'Fine Line', 174, 'Pop', 95, const Color(0xFFE91E63), const Color(0xFFFF5722), Icons.sunny),
      ('Levitating', 'Dua Lipa', 'Future Nostalgia', 203, 'Nu-Disco', 103, const Color(0xFF8E24AA), const Color(0xFF3949AB), Icons.auto_awesome_rounded),
      ('Don\'t Start Now', 'Dua Lipa', 'Future Nostalgia', 183, 'Nu-Disco', 124, const Color(0xFFAD1457), const Color(0xFF6A1B9A), Icons.album_rounded),
      ('Stay', 'The Kid LAROI & Justin Bieber', 'F*CK LOVE 3', 141, 'Pop', 170, const Color(0xFF3F51B5), const Color(0xFF00BCD4), Icons.repeat_one_rounded),
      ('Bad Guy', 'Billie Eilish', 'When We All Fall Asleep...', 194, 'Pop', 135, const Color(0xFFFFEE58), const Color(0xFF7CB342), Icons.mood_bad_rounded),
      ('Shape of You', 'Ed Sheeran', '÷ (Divide)', 233, 'Pop', 96, const Color(0xFF00BCD4), const Color(0xFF009688), Icons.music_note_rounded),
      ('Bad Habits', 'Ed Sheeran', '= (Equals)', 231, 'Pop', 126, const Color(0xFFD32F2F), const Color(0xFFFF1744), Icons.local_fire_department),
      ('Circles', 'Post Malone', "Hollywood's Bleeding", 215, 'Pop', 120, const Color(0xFFFFB74D), const Color(0xFFF57C00), Icons.rotate_right_rounded),
      ('Sunflower', 'Post Malone & Swae Lee', 'Spider-Man Soundtrack', 158, 'Hip-Hop', 90, const Color(0xFFFFEB3B), const Color(0xFFFF9800), Icons.filter_vintage_rounded),
      ('Uptown Funk', 'Mark Ronson ft. Bruno Mars', 'Uptown Special', 270, 'Funk', 115, const Color(0xFFD32F2F), const Color(0xFFFFB300), Icons.fireplace_rounded),
      ('24K Magic', 'Bruno Mars', '24K Magic', 226, 'Funk / Pop', 107, const Color(0xFFFFD700), const Color(0xFFFF6F00), Icons.diamond_rounded),
      ('Locked Out of Heaven', 'Bruno Mars', 'Unorthodox Jukebox', 233, 'Pop', 144, const Color(0xFFFFA000), const Color(0xFFE65100), Icons.lock_open_rounded),
      ('Anti-Hero', 'Taylor Swift', 'Midnights', 200, 'Pop', 97, const Color(0xFF3F51B5), const Color(0xFF5C6BC0), Icons.nightlight_round),
      ('Cruel Summer', 'Taylor Swift', 'Lover', 178, 'Pop', 170, const Color(0xFFF06292), const Color(0xFFBA68C8), Icons.wb_sunny_rounded),

      // 46-60: Rock & Indie Anthems
      ('Do I Wanna Know?', 'Arctic Monkeys', 'AM', 272, 'Rock', 85, const Color(0xFF424242), const Color(0xFF212121), Icons.graphic_eq_rounded),
      ('R U Mine?', 'Arctic Monkeys', 'AM', 201, 'Rock', 97, const Color(0xFF37474F), const Color(0xFF263238), Icons.mic_rounded),
      ('505', 'Arctic Monkeys', 'Favourite Worst Nightmare', 253, 'Rock', 140, const Color(0xFF616161), const Color(0xFF212121), Icons.hotel_rounded),
      ('The Less I Know The Better', 'Tame Impala', 'Currents', 216, 'Indie Rock', 117, const Color(0xFF9C27B0), const Color(0xFF3F51B5), Icons.waves_rounded),
      ('Borderline', 'Tame Impala', 'The Slow Rush', 237, 'Indie Rock', 98, const Color(0xFFFF8A65), const Color(0xFFFFB74D), Icons.grain_rounded),
      ('Clocks', 'Coldplay', 'A Rush of Blood to the Head', 307, 'Rock', 131, const Color(0xFF42A5F5), const Color(0xFF1565C0), Icons.piano_rounded),
      ('Viva La Vida', 'Coldplay', 'Viva la Vida', 241, 'Pop Rock', 138, const Color(0xFFEF5350), const Color(0xFFB71C1C), Icons.military_tech_rounded),
      ('Yellow', 'Coldplay', 'Parachutes', 269, 'Rock', 87, const Color(0xFFFFEB3B), const Color(0xFFFBC02D), Icons.lightbulb_rounded),
      ('The Scientist', 'Coldplay', 'A Rush of Blood to the Head', 309, 'Rock', 146, const Color(0xFF78909C), const Color(0xFF455A64), Icons.science_rounded),
      ('Feel Good Inc.', 'Gorillaz', 'Demon Days', 221, 'Rock', 139, const Color(0xFF26A69A), const Color(0xFF00695C), Icons.smart_toy_rounded),
      ('Clint Eastwood', 'Gorillaz', 'Gorillaz', 340, 'Rock', 84, const Color(0xFF00897B), const Color(0xFF004D40), Icons.cloud_rounded),
      ('On Melancholy Hill', 'Gorillaz', 'Plastic Beach', 233, 'Indie Pop', 120, const Color(0xFF80CBC4), const Color(0xFF00897B), Icons.water_drop_rounded),
      ('Bohemian Rhapsody', 'Queen', 'A Night at the Opera', 354, 'Rock', 72, const Color(0xFF8E24AA), const Color(0xFFC2185B), Icons.star_border_purple500_rounded),
      ('Radioactive', 'Imagine Dragons', 'Night Visions', 186, 'Rock', 136, const Color(0xFFFF5722), const Color(0xFFBF360C), Icons.warning_amber_rounded),
      ('Believer', 'Imagine Dragons', 'Evolve', 204, 'Rock', 125, const Color(0xFF2196F3), const Color(0xFF0D47A1), Icons.fitness_center_rounded),

      // 61-75: Latin / Urbano / Reggaeton Hits
      ('Dakiti', 'Bad Bunny x Jhay Cortez', 'El Último Tour Del Mundo', 205, 'Urbano', 110, const Color(0xFF5E35B1), const Color(0xFF1E88E5), Icons.audiotrack_rounded),
      ('Yonaguni', 'Bad Bunny', 'Yonaguni', 206, 'Urbano', 180, const Color(0xFF3949AB), const Color(0xFF00ACC1), Icons.language_rounded),
      ('Ojitos Lindos', 'Bad Bunny ft. Bomba Estéreo', 'Un Verano Sin Ti', 258, 'Urbano', 80, const Color(0xFFFF7043), const Color(0xFFFFCA28), Icons.favorite_rounded),
      ('Me Porto Bonito', 'Bad Bunny ft. Chencho Corleone', 'Un Verano Sin Ti', 178, 'Urbano', 92, const Color(0xFFE53935), const Color(0xFF8E24AA), Icons.whatshot_rounded),
      ('Titi Me Preguntó', 'Bad Bunny', 'Un Verano Sin Ti', 243, 'Urbano', 106, const Color(0xFFFFB300), const Color(0xFFF4511E), Icons.celebration_rounded),
      ('Despechá', 'ROSALÍA', 'MOTOMAMI+', 157, 'Pop / Urbano', 130, const Color(0xFFFF4081), const Color(0xFFFF5252), Icons.beach_access_rounded),
      ('Saoko', 'ROSALÍA', 'MOTOMAMI', 137, 'Urbano', 100, const Color(0xFFD50000), const Color(0xFF212121), Icons.two_wheeler_rounded),
      ('Bzrp Music Sessions #52', 'Bizarrap & Quevedo', 'Bzrp Sessions', 198, 'Urbano', 128, const Color(0xFF00B0FF), const Color(0xFF0091EA), Icons.speaker_group_rounded),
      ('Bzrp Music Sessions #53', 'Bizarrap & Shakira', 'Bzrp Sessions', 217, 'Pop / Urbano', 122, const Color(0xFFFFD600), const Color(0xFFFF6D00), Icons.auto_awesome_rounded),
      ('La Bachata', 'Manuel Turizo', '2000', 162, 'Latino', 125, const Color(0xFF00897B), const Color(0xFF00ACC1), Icons.music_note_rounded),
      ('Provenza', 'KAROL G', 'MAÑANA SERÁ BONITO', 210, 'Urbano', 111, const Color(0xFF80DEEA), const Color(0xFF00B8D4), Icons.wb_sunny_rounded),
      ('TQG', 'KAROL G ft. Shakira', 'MAÑANA SERÁ BONITO', 199, 'Urbano', 90, const Color(0xFF00E676), const Color(0xFF00B0FF), Icons.local_fire_department_rounded),
      ('Ella Baila Sola', 'Eslabon Armado & Peso Pluma', 'Desvelado', 165, 'Regional', 148, const Color(0xFFFFB74D), const Color(0xFF8D6E63), Icons.queue_music_rounded),
      ('Monotonía', 'Shakira & Ozuna', 'Monotonía', 158, 'Latino', 136, const Color(0xFF9C27B0), const Color(0xFFE91E63), Icons.heart_broken_rounded),
      ('Danza Kuduro', 'Don Omar ft. Lucenzo', 'Meet The Orphans', 199, 'Latino', 130, const Color(0xFFFF9800), const Color(0xFFFFC107), Icons.celebration_rounded),

      // 76-90: Focus Tech & Coding Special Tracks (Para Ingenieros de Sistemas)
      ('DevOps Synth Theme', 'Terminal Beats', 'Kubernetes Flow', 180, 'Focus Tech', 128, const Color(0xFF00B0FF), const Color(0xFF00E5FF), Icons.terminal_rounded),
      ('Linux Kernel Groove', 'OpenSource Collective', 'Root Access', 210, 'Focus Tech', 120, const Color(0xFF00C853), const Color(0xFF64DD17), Icons.code_rounded),
      ('Async Await Rhythm', 'FullStack Band', 'Event Loop Vol. 1', 195, 'Focus Tech', 115, const Color(0xFFFFD600), const Color(0xFFFFAB00), Icons.sync_rounded),
      ('Microservices Drop', 'Architect DJ', 'Distributed Beats', 225, 'Focus Tech', 128, const Color(0xFFAA00FF), const Color(0xFF7C4DFF), Icons.lan_rounded),
      ('Binary Pulse', 'Bytecode', 'Hexadecimal Dreams', 205, 'Focus Tech', 118, const Color(0xFF00B8D4), const Color(0xFF0091EA), Icons.developer_board_rounded),
      ('Bug Fix in Production', 'Hotfix Hero', 'Zero Downtime', 170, 'Focus Tech', 132, const Color(0xFFFF5252), const Color(0xFFFF1744), Icons.bug_report_rounded),
      ('Docker Container Vibe', 'DevOps Synth', 'Compose Up', 190, 'Focus Tech', 122, const Color(0xFF2979FF), const Color(0xFF2962FF), Icons.inventory_2_rounded),
      ('Neural Network Flow', 'Deep Learning Labs', 'Weights & Biases', 240, 'Focus Tech', 110, const Color(0xFF651FFF), const Color(0xFF6200EA), Icons.hub_rounded),
      ('Cloud Native Odyssey', 'AWS & GCP Mix', 'Multi-Region High Availability', 215, 'Focus Tech', 126, const Color(0xFFFF6D00), const Color(0xFFDD2C00), Icons.cloud_done_rounded),
      ('Zero Bug Serenade', 'Refactor Studio', 'Clean Architecture', 200, 'Focus Tech', 108, const Color(0xFF00E676), const Color(0xFF00C853), Icons.verified_rounded),
      ('Stack Overflow Lullaby', 'Senior Dev', 'Accepted Answer', 185, 'Focus Tech', 112, const Color(0xFFFF7043), const Color(0xFFF4511E), Icons.help_outline_rounded),
      ('Git Commit & Push', 'Version Control Sound', 'Main Branch', 195, 'Focus Tech', 124, const Color(0xFF4CAF50), const Color(0xFF2E7D32), Icons.commit_rounded),
      ('CI/CD Pipeline Flow', 'Automation Groove', 'Build Succeeded', 210, 'Focus Tech', 130, const Color(0xFF00BCD4), const Color(0xFF0097A7), Icons.precision_manufacturing_rounded),
      ('Cyberpunk 2077 Theme', 'Marcin Przybyłowicz', 'Night City Beats', 245, 'Focus Tech', 135, const Color(0xFFFFFF00), const Color(0xFF00E5FF), Icons.electric_bolt_rounded),
      ('Quantum Computing Beat', 'Qubit Ensemble', 'Superposition', 230, 'Focus Tech', 120, const Color(0xFF7C4DFF), const Color(0xFF651FFF), Icons.blur_linear_rounded),

      // 91-105: Hip-Hop & Rap Hits
      ('HUMBLE.', 'Kendrick Lamar', 'DAMN.', 177, 'Hip-Hop', 150, const Color(0xFFD50000), const Color(0xFF212121), Icons.mic_external_on_rounded),
      ('DNA.', 'Kendrick Lamar', 'DAMN.', 185, 'Hip-Hop', 140, const Color(0xFFC62828), const Color(0xFF37474F), Icons.fingerprint_rounded),
      ('God\'s Plan', 'Drake', 'Scorpion', 198, 'Hip-Hop', 77, const Color(0xFFFFA000), const Color(0xFF795548), Icons.wb_twilight_rounded),
      ('Hotline Bling', 'Drake', 'Views', 267, 'Hip-Hop', 135, const Color(0xFFE91E63), const Color(0xFFFF80AB), Icons.phone_in_talk_rounded),
      ('SICKO MODE', 'Travis Scott', 'ASTROWORLD', 312, 'Hip-Hop', 155, const Color(0xFF263238), const Color(0xFFFF5722), Icons.rocket_launch_rounded),
      ('goosebumps', 'Travis Scott', 'Birds in the Trap', 243, 'Hip-Hop', 130, const Color(0xFF37474F), const Color(0xFF4A148C), Icons.air_rounded),
      ('Industry Baby', 'Lil Nas X & Jack Harlow', 'MONTERO', 212, 'Hip-Hop', 150, const Color(0xFFFF6D00), const Color(0xFFFFD600), Icons.campaign_rounded),
      ('MONTERO (Call Me By Your Name)', 'Lil Nas X', 'MONTERO', 137, 'Hip-Hop', 179, const Color(0xFFC2185B), const Color(0xFF880E4F), Icons.fireplace_rounded),
      ('Lose Yourself', 'Eminem', '8 Mile', 326, 'Hip-Hop', 171, const Color(0xFF424242), const Color(0xFF212121), Icons.timer_rounded),
      ('Without Me', 'Eminem', 'The Eminem Show', 290, 'Hip-Hop', 112, const Color(0xFF757575), const Color(0xFFB71C1C), Icons.radio_rounded),
      ('Still D.R.E.', 'Dr. Dre ft. Snoop Dogg', '2001', 270, 'Hip-Hop', 93, const Color(0xFF2E7D32), const Color(0xFF1B5E20), Icons.piano_rounded),
      ('In Da Club', '50 Cent', 'Get Rich or Die Tryin\'', 193, 'Hip-Hop', 90, const Color(0xFF5D4037), const Color(0xFF3E2723), Icons.cake_rounded),
      ('Stronger', 'Kanye West', 'Graduation', 311, 'Hip-Hop / Electro', 123, const Color(0xFF7B1FA2), const Color(0xFFE040FB), Icons.flash_on_rounded),
      ('Gold Digger', 'Kanye West ft. Jamie Foxx', 'Late Registration', 208, 'Hip-Hop', 107, const Color(0xFFFFD600), const Color(0xFFFF6D00), Icons.monetization_on_rounded),
      ('All The Stars', 'Kendrick Lamar & SZA', 'Black Panther Soundtrack', 232, 'Hip-Hop / R&B', 97, const Color(0xFF4527A0), const Color(0xFF283593), Icons.star_purple500_rounded),

      // 106-120: Timeless Classics & Alternative
      ('Glimpse of Us', 'Joji', 'SMITHEREENS', 233, 'R&B / Soul', 85, const Color(0xFF78909C), const Color(0xFF37474F), Icons.piano_rounded),
      ('SLOW DANCING IN THE DARK', 'Joji', 'BALLADS 1', 209, 'R&B / Soul', 89, const Color(0xFF311B92), const Color(0xFF4A148C), Icons.nightlight_round),
      ('Billie Jean', 'Michael Jackson', 'Thriller', 294, 'Pop / Funk', 117, const Color(0xFFD50000), const Color(0xFF212121), Icons.flare_rounded),
      ('Beat It', 'Michael Jackson', 'Thriller', 258, 'Rock / Pop', 139, const Color(0xFFC62828), const Color(0xFFFF6D00), Icons.local_fire_department_rounded),
      ('Smooth Criminal', 'Michael Jackson', 'Bad', 257, 'Pop', 118, const Color(0xFF37474F), const Color(0xFF263238), Icons.directions_walk_rounded),
      ('Careless Whisper', 'George Michael', 'Make It Big', 302, 'Pop / Soul', 76, const Color(0xFF880E4F), const Color(0xFF4A148C), Icons.music_note_rounded),
      ('Everybody Wants To Rule The World', 'Tears For Fears', 'Songs from the Big Chair', 251, 'Pop Rock', 112, const Color(0xFF0097A7), const Color(0xFF006064), Icons.public_rounded),
      ('Take On Me', 'a-ha', 'Hunting High and Low', 225, 'Synthpop', 169, const Color(0xFF0288D1), const Color(0xFF01579B), Icons.speed_rounded),
      ('Sweet Child O\' Mine', 'Guns N\' Roses', 'Appetite for Destruction', 356, 'Rock', 125, const Color(0xFFE64A19), const Color(0xFFBF360C), Icons.electric_bolt_rounded),
      ('Smells Like Teen Spirit', 'Nirvana', 'Nevermind', 301, 'Rock', 117, const Color(0xFF00838F), const Color(0xFF004D40), Icons.waves_rounded),
      ('Wonderwall', 'Oasis', '(What\'s the Story) Morning Glory?', 258, 'Rock', 87, const Color(0xFF6D4C41), const Color(0xFF3E2723), Icons.music_note_rounded),
      ('Mr. Brightside', 'The Killers', 'Hot Fuss', 222, 'Rock', 148, const Color(0xFF00ACC1), const Color(0xFF006064), Icons.flash_on_rounded),
      ('Somebody That I Used to Know', 'Gotye ft. Kimbra', 'Making Mirrors', 244, 'Indie Pop', 129, const Color(0xFF689F38), const Color(0xFF33691E), Icons.palette_rounded),
      ('Counting Stars', 'OneRepublic', 'Native', 257, 'Pop Rock', 122, const Color(0xFF7B1FA2), const Color(0xFF4A148C), Icons.star_rate_rounded),
      ('Rolling in the Deep', 'Adele', '21', 228, 'Soul / Pop', 105, const Color(0xFF4E342E), const Color(0xFF212121), Icons.album_rounded),
    ];

    return List.generate(rawSongs.length, (index) {
      final item = rawSongs[index];
      final title = item.$1;
      final artist = item.$2;
      final album = item.$3;
      final durationSec = item.$4;
      final genre = item.$5;
      final bpm = item.$6;
      final color1 = item.$7;
      final color2 = item.$8;
      final icon = item.$9;

      final mins = durationSec ~/ 60;
      final secs = durationSec % 60;
      final durationStr = '$mins:${secs.toString().padLeft(2, '0')}';

      return Song(
        id: '${index + 1}',
        title: title,
        artist: artist,
        album: album,
        duration: durationStr,
        durationSeconds: durationSec,
        genre: genre,
        bpm: bpm,
        coverColor: color1,
        secondaryColor: color2,
        coverIcon: icon,
        segments: [
          SongSegment(
            name: 'Outro Final (Últimos 20s)',
            startSeconds: durationSec > 20 ? durationSec - 20 : 0,
            endSeconds: durationSec,
            isViralHighlight: true,
          ),
          SongSegment(
            name: 'Beat Drop / Coro Principal',
            startSeconds: durationSec > 60 ? 30 : 0,
            endSeconds: durationSec > 60 ? 60 : durationSec,
            isViralHighlight: true,
          ),
        ],
      );
    });
  }

  static final List<Song> _catalog = _generateCatalog();

  static final List<RadioStation> _stations = [
    const RadioStation(
      id: 'radio_tech',
      name: 'Radio Dev & Systems',
      genre: 'Electro & Synthwave para Programar',
      description: 'Música electrónica con cápsulas de tecnología, cloud y arquitectura de software.',
      icon: Icons.developer_mode_rounded,
      color1: Color(0xFF6A11CB),
      color2: Color(0xFF2575FC),
      songIds: ['1', '2', '3', '7', '10'],
      hostTopic: 'Ingeniería de Sistemas e IA',
    ),
    const RadioStation(
      id: 'radio_romantica',
      name: 'Radio Baladas & Chill',
      genre: 'Acústico y Reflexión',
      description: 'Canciones suaves y pausas con reflexiones sobre bienestar, vida y calma.',
      icon: Icons.favorite_rounded,
      color1: Color(0xFFFF416C),
      color2: Color(0xFFFF4B2B),
      songIds: ['4', '5', '9', '12'],
      hostTopic: 'Reflexión y Desconexión',
    ),
    const RadioStation(
      id: 'radio_energy',
      name: 'Radio Peak Energy Mix',
      genre: 'Dance y Hits Energéticos',
      description: 'Ritmo acelerado para entrenar o sprints de código.',
      icon: Icons.bolt_rounded,
      color1: Color(0xFFF7971E),
      color2: Color(0xFFFFD200),
      songIds: ['2', '5', '6', '11', '17'],
      hostTopic: 'Productividad y Novedades Tech',
    ),
  ];

  static final List<AiHostCapsule> _hostCapsules = [
    const AiHostCapsule(
      hostName: 'Locutor IA: Turing DJ',
      topicBadge: 'NOTICIA TECH / DEV',
      message:
          '¡Hola Piero! Un dato rápido para tu sesión de código: los modelos de IA autónomos ahora optimizan queries de bases de datos distribuidas en tiempo real. ¡Continuamos con la mejor música para mantener el foco en la terminal!',
      durationSeconds: 12,
    ),
    const AiHostCapsule(
      hostName: 'Locutor IA: Turing DJ',
      topicBadge: 'REFLEXIÓN DE SISTEMAS',
      message:
          'Recordatorio para desarrolladores: "La optimización prematura es la raíz de todos los males". Diseña simple, mide primero y refactoriza con calma. ¡Sigue con este beat que viene a continuación!',
      durationSeconds: 10,
    ),
    const AiHostCapsule(
      hostName: 'Locutor IA: Ada Host',
      topicBadge: 'ARQUITECTURA CLOUD',
      message:
          'Estás escuchando Radio Dev. ¿Sabías que el 80% de los fallos en microservicios se deben a timeouts mal configurados y falta de circuit breakers? Ya lo sabes, cuida tu backend mientras suena este tema.',
      durationSeconds: 11,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _listenScrollController.addListener(_onScrollChanged);

    final queue = QueueHandler(library: _catalog);
    final snippet = SnippetLoopHandler(
      playlist: [
        MixItem(song: _catalog[0], segment: _catalog[0].segments[0], loopCount: 3),
        MixItem(song: _catalog[1], segment: _catalog[1].segments[0], loopCount: 2),
        MixItem(song: _catalog[2], segment: _catalog[2].segments[0], loopCount: 3),
      ],
    );
    final radio = AiRadioHostHandler(stations: _stations, capsules: _hostCapsules);

    _mediator = MusicPlaybackMediator(
      queueHandler: queue,
      snippetHandler: snippet,
      radioHandler: radio,
    );
  }

  void _onScrollChanged() {
    final show = _listenScrollController.hasClients && _listenScrollController.offset > 240;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  @override
  void dispose() {
    _listenScrollController.removeListener(_onScrollChanged);
    _listenScrollController.dispose();
    _inPlaylistSearchController.dispose();
    _searchTabController.dispose();
    _searchFocusNode.dispose();
    _mediator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _mediator,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildListenNowTab(),
                  _buildDjMixStudioTab(),
                  _buildAiRadioTab(),
                  _buildLibraryTab(),
                  _buildSearchTab(),
                ],
              ),

              // Botón flotante para buscar en la lista o volver arriba rápidamente
              if (_showScrollToTop && _selectedTabIndex == 0)
                Positioned(
                  right: 20,
                  bottom: 156, // Justo encima del mini-reproductor flotante
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            _listenScrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            );
                            _searchFocusNode.requestFocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22222A).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFFA2D48).withValues(alpha: 0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.filter_list_rounded, color: Color(0xFFFA2D48), size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Buscar en lista',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_upward_rounded, color: Colors.white70, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Banner animado si el locutor IA está hablando
              if (_mediator.radioHandler.isHostSpeaking &&
                  _mediator.radioHandler.activeCapsule != null)
                _buildAiHostSpeakingOverlay(),

              // Mini reproductor y barra inferior flotante
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingMiniPlayer(),
                    _buildAppleMusicTabBar(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // OVERLAY DEL LOCUTOR IA
  // ---------------------------------------------------------------------------
  Widget _buildAiHostSpeakingOverlay() {
    final capsule = _mediator.radioHandler.activeCapsule!;
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A11CB).withValues(alpha: 0.5),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          capsule.hostName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            capsule.topicBadge,
                            style: const TextStyle(
                              color: Color(0xFF00FFC6),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      capsule.message,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.mic_rounded, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        const Text(
                          'Locutor IA al aire • Cápsula para Ing. de Sistemas',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _mediator.notify(PlaybackEvent.dismissHostSpeech),
                          child: const Text(
                            'Omitir',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PESTAÑA 1: ESCUCHAR
  // ---------------------------------------------------------------------------
  Widget _buildListenNowTab() {
    final filteredSongs = _catalog.where((song) {
      final q = _inPlaylistSearchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q) ||
          song.album.toLowerCase().contains(q) ||
          '${song.bpm}'.contains(q);

      final isFav = _mediator.queueHandler.favoriteSongIds.contains(song.id);
      final matchesGenre = switch (_selectedGenreFilter) {
        'Todas' => true,
        'Favoritas ⭐' => isFav,
        'BPM > 120' => song.bpm > 120,
        _ => song.genre.toLowerCase().contains(_selectedGenreFilter.toLowerCase()),
      };

      return matchesQuery && matchesGenre;
    }).toList();

    final topPadding = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      controller: _listenScrollController,
      slivers: [
        // Cabecera Fija / Sticky con Escuchar + Búsqueda y Filtros protegidos de la barra de estado y notch
        SliverPersistentHeader(
          pinned: true,
          delegate: _PlaylistSearchStickyHeaderDelegate(
            topPadding: topPadding,
            searchController: _inPlaylistSearchController,
            searchFocusNode: _searchFocusNode,
            searchQuery: _inPlaylistSearchQuery,
            selectedGenreFilter: _selectedGenreFilter,
            totalCount: filteredSongs.length,
            onSearchChanged: (val) => setState(() => _inPlaylistSearchQuery = val),
            onClearSearch: () {
              _inPlaylistSearchController.clear();
              setState(() => _inPlaylistSearchQuery = '');
            },
            onGenreSelected: (tag) => setState(() => _selectedGenreFilter = tag),
          ),
        ),

        // Acceso directo a Radio IA
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedTabIndex = 2),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.podcasts_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MEDIATOR PATTERN • IA HOST',
                            style: TextStyle(
                              color: Color(0xFF00FFC6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Radio con Locutor IA Tech',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Coordinación desacoplada entre música y cápsulas.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Acceso directo a DJ Mix
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFA2D48).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA2D48).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Color(0xFFFA2D48), size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SNIPPET LOOP ENGINE',
                            style: TextStyle(
                              color: Color(0xFFFA2D48),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Mixea tus Partes Favoritas',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Controlador de bucles 3x orquestado por el Mediador.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Lista de canciones filtradas
        if (filteredSongs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, color: Colors.white30, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No se encontraron canciones en esta playlist para "$_inPlaylistSearchQuery"',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFFA2D48)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Restablecer filtro'),
                    onPressed: () {
                      _inPlaylistSearchController.clear();
                      setState(() {
                        _inPlaylistSearchQuery = '';
                        _selectedGenreFilter = 'Todas';
                      });
                    },
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = filteredSongs[index];
                  final isSelected = song.id == _mediator.currentSong.id &&
                      _mediator.mode == PlaybackMode.standard;

                  return _buildSongListTile(song, index: index + 1, isSelected: isSelected);
                },
                childCount: filteredSongs.length,
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PESTAÑA 2: DJ MIX STUDIO
  // ---------------------------------------------------------------------------
  Widget _buildDjMixStudioTab() {
    final playlist = _mediator.snippetHandler.playlist;

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DJ Mix Studio',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFA2D48).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Color(0xFFFA2D48), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Mediator Sync',
                              style: TextStyle(
                                color: Color(0xFFFA2D48),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cada fragmento repite su bucle (ej: 3 veces) y el Mediador coordina la transición hacia la siguiente pista sin acoplar la UI.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Botón reproducir / pausar mix
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA2D48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(
                _mediator.mode == PlaybackMode.snippetMix && _mediator.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                size: 26,
              ),
              label: Text(
                _mediator.mode == PlaybackMode.snippetMix && _mediator.isPlaying
                    ? 'Pausar DJ Mix Activo'
                    : 'Reproducir Secuencia DJ Mix',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                if (_mediator.mode == PlaybackMode.snippetMix && _mediator.isPlaying) {
                  _mediator.notify(PlaybackEvent.playPauseToggled);
                } else {
                  _mediator.notify(PlaybackEvent.mixSnippetSelected,
                      payload: _mediator.snippetHandler.currentMixIndex);
                }
              },
            ),
          ),
        ),

        // Estado del mix activo
        if (_mediator.mode == PlaybackMode.snippetMix)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFA2D48)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.loop_rounded, color: Color(0xFFFA2D48), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sonando: ${_mediator.currentSong.title} (${_mediator.snippetHandler.currentItem.segment.name})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bucle ${_mediator.snippetHandler.currentItem.currentLoop} de ${_mediator.snippetHandler.currentItem.loopCount} veces • Orquestado por Mediador',
                          style: const TextStyle(color: Color(0xFFFA2D48), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Lista de items del mix
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = playlist[index];
                final isCurrent = _mediator.mode == PlaybackMode.snippetMix &&
                    _mediator.snippetHandler.currentMixIndex == index;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF262634) : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? const Color(0xFFFA2D48) : Colors.white10,
                      width: isCurrent ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [item.song.coverColor, item.song.secondaryColor],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.song.coverIcon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.song.title,
                                  style: TextStyle(
                                    color: isCurrent ? const Color(0xFFFA2D48) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Segmento: ${item.segment.name}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isCurrent && _mediator.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: const Color(0xFFFA2D48),
                              size: 32,
                            ),
                            onPressed: () => _mediator.notify(PlaybackEvent.mixSnippetSelected, payload: index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 8),

                      // Selector de fragmento
                      Row(
                        children: [
                          const Icon(Icons.straighten_rounded, color: Colors.white38, size: 18),
                          const SizedBox(width: 8),
                          const Text('Parte elegida:', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                          const Spacer(),
                          DropdownButton<SongSegment>(
                            dropdownColor: const Color(0xFF2C2C2E),
                            value: item.song.segments.contains(item.segment)
                                ? item.segment
                                : item.song.segments.first,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            underline: const SizedBox(),
                            items: item.song.segments.map((seg) {
                              return DropdownMenuItem<SongSegment>(
                                value: seg,
                                child: Text(
                                  seg.name,
                                  style: TextStyle(
                                    color: seg.isViralHighlight ? const Color(0xFF00FFC6) : Colors.white,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newSeg) {
                              if (newSeg != null) {
                                _mediator.notify(
                                  PlaybackEvent.changeSnippetSegment,
                                  payload: {'index': index, 'segment': newSeg},
                                );
                              }
                            },
                          ),
                        ],
                      ),

                      // Selector de repeticiones (ej: 3 veces)
                      Row(
                        children: [
                          const Icon(Icons.repeat_rounded, color: Colors.white38, size: 18),
                          const SizedBox(width: 8),
                          const Text('Bucles a repetir:', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                          const Spacer(),
                          Wrap(
                            spacing: 6,
                            children: [1, 2, 3, 5].map((count) {
                              final isSelected = item.loopCount == count;
                              return GestureDetector(
                                onTap: () {
                                  _mediator.notify(
                                    PlaybackEvent.changeLoopCount,
                                    payload: {'index': index, 'count': count},
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFA2D48) : const Color(0xFF2C2C2E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${count}x',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              childCount: playlist.length,
            ),
          ),
        ),

        // Botón agregar pista
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar otra canción al DJ Mix'),
              onPressed: () {
                final nextSong = _catalog[playlist.length % _catalog.length];
                _mediator.notify(PlaybackEvent.addSongToMix, payload: nextSong);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Añadida "${nextSong.title}" en bucle 3x al Mediador.'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFFFA2D48),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PESTAÑA 3: RADIO IA & LOCUTOR
  // ---------------------------------------------------------------------------
  Widget _buildAiRadioTab() {
    final radio = _mediator.radioHandler;

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Radio IA & Locutor',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El Mediador coordina las intervenciones del locutor virtual entre canciones sin congelar el flujo de reproducción.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Configuración del locutor IA
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mic_external_on_rounded, color: Color(0xFFFA2D48), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Locutor Virtual Inteligente',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Switch(
                      value: radio.isAiHostActive,
                      activeThumbColor: const Color(0xFFFA2D48),
                      onChanged: (val) {
                        _mediator.notify(PlaybackEvent.toggleAiHostActive, payload: val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tema de interés para el locutor:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Ingeniería de Sistemas y Tech',
                    'Arquitectura Cloud & DevOps',
                    'Reflexión y Productividad',
                    'Curiosidades Musicales',
                  ].map((topic) {
                    final isSelected = radio.selectedInterest == topic;
                    return GestureDetector(
                      onTap: () {
                        _mediator.notify(PlaybackEvent.changeHostInterest, payload: topic);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFA2D48) : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          topic,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00FFC6),
                    side: const BorderSide(color: Color(0xFF00FFC6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.campaign_rounded, size: 20),
                  label: const Text('Probar intervención del Locutor ahora'),
                  onPressed: () {
                    _mediator.notify(PlaybackEvent.triggerHostSpeechManually);
                  },
                ),
              ],
            ),
          ),
        ),

        // Emisoras
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 140),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final station = _stations[index];
                final isPlayingThis = _mediator.mode == PlaybackMode.aiRadio &&
                    _mediator.radioHandler.activeStation?.id == station.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [station.color1, station.color2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        _mediator.notify(PlaybackEvent.radioStationSelected, payload: station);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                              child: Icon(station.icon, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    station.genre.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    station.name,
                                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    station.description,
                                    style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white,
                              child: Icon(
                                isPlayingThis && _mediator.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: _stations.length,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PESTAÑA 4: BIBLIOTECA
  // ---------------------------------------------------------------------------
  Widget _buildLibraryTab() {
    final upNextSongs = _mediator.queueHandler.queue
        .where((song) => song.id != _mediator.currentSong.id)
        .take(3)
        .toList(growable: false);
    final libraryMenuItems = [
      {'title': 'Playlists', 'icon': Icons.queue_music_rounded},
      {'title': 'Mis DJ Mixes Guardados', 'icon': Icons.tune_rounded},
      {'title': 'Emisoras de Radio Favoritas', 'icon': Icons.radio_rounded},
      {'title': 'Artistas', 'icon': Icons.music_note_rounded},
      {'title': 'Canciones (+${_catalog.length} canciones)', 'icon': Icons.audiotrack_rounded},
    ];

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: const Text(
                'Biblioteca',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: libraryMenuItems.map((item) {
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: Icon(item['icon'] as IconData, color: const Color(0xFFFA2D48), size: 26),
                    title: Text(
                      item['title'] as String,
                      style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 64),
                ],
              );
            }).toList(),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 140),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.queue_play_next_rounded, color: Color(0xFFFA2D48), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Cola de reproducción (Demo)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (upNextSongs.isEmpty)
                  const Text(
                    'No hay canciones en cola por ahora.',
                    style: TextStyle(color: Colors.white54, fontSize: 12.5),
                  )
                else
                  ...upNextSongs.map(
                    (song) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${song.title} — ${song.artist}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PESTAÑA 5: BUSCAR
  // ---------------------------------------------------------------------------
  Widget _buildSearchTab() {
    final filteredSongs = _catalog.where((song) {
      final q = _searchTabQuery.trim().toLowerCase();
      final isFavorite = _mediator.queueHandler.favoriteSongIds.contains(song.id);
      final matchesQuery = q.isEmpty ||
          song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q) ||
          song.album.toLowerCase().contains(q) ||
          '${song.bpm}'.contains(q);

      final matchesFilter = switch (_searchTabFilter) {
        'Todas' => true,
        'Favoritas ⭐' => isFavorite,
        'Focus Tech' => song.genre.toLowerCase().contains('focus tech'),
        'BPM > 120' => song.bpm > 120,
        _ => song.genre.toLowerCase().contains(_searchTabFilter.toLowerCase()),
      };

      return matchesQuery && matchesFilter;
    }).toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buscar',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _searchTabQuery.isNotEmpty
                            ? const Color(0xFFFA2D48).withValues(alpha: 0.6)
                            : Colors.white12,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.white54, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchTabController,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'Canciones, artistas, álbumes o BPM...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                              border: InputBorder.none,
                            ),
                            onChanged: (value) => setState(() => _searchTabQuery = value),
                          ),
                        ),
                        if (_searchTabQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchTabController.clear();
                              setState(() => _searchTabQuery = '');
                            },
                            child: const Icon(Icons.cancel_rounded, color: Colors.white54, size: 18),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['Todas', 'Favoritas ⭐', 'Focus Tech', 'Electrónica', 'Synthwave', 'Hip-Hop', 'BPM > 120'].map((filter) {
                        final isSelected = _searchTabFilter == filter;
                        return GestureDetector(
                          onTap: () => setState(() => _searchTabFilter = filter),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFA2D48) : const Color(0xFF2A2A2F),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (filteredSongs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, color: Colors.white30, size: 44),
                  const SizedBox(height: 10),
                  const Text(
                    'No hay resultados con ese filtro.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _searchTabController.clear();
                      setState(() {
                        _searchTabQuery = '';
                        _searchTabFilter = 'Todas';
                      });
                    },
                    child: const Text('Limpiar búsqueda'),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 140),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = filteredSongs[index];
                  final isSelected = song.id == _mediator.currentSong.id &&
                      _mediator.mode == PlaybackMode.standard;
                  return _buildSongListTile(song, index: index + 1, isSelected: isSelected);
                },
                childCount: filteredSongs.length,
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TILE DE CANCIÓN
  // ---------------------------------------------------------------------------
  Widget _buildSongListTile(Song song, {required int index, required bool isSelected}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _mediator.notify(PlaybackEvent.songSelected, payload: song),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: isSelected && _mediator.isPlaying
                      ? const Icon(Icons.equalizer_rounded, color: Color(0xFFFA2D48), size: 18)
                      : Text(
                          '$index',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFFFA2D48) : Colors.white38,
                          ),
                        ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [song.coverColor, song.secondaryColor]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(song.coverIcon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFFFA2D48) : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${song.artist} • ${song.bpm} BPM',
                        style: const TextStyle(fontSize: 13, color: Colors.white54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  song.duration,
                  style: const TextStyle(color: Colors.white38, fontSize: 12.5),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, color: Colors.white38, size: 20),
                  onPressed: () => _showInfoSnackBar('Opciones de "${song.title}" disponibles en próxima iteración.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MINI-REPRODUCTOR FLOTANTE
  // ---------------------------------------------------------------------------
  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2A2A32),
      ),
    );
  }

  Widget _buildFloatingMiniPlayer() {
    String modeLabel = '';
    Color modeBadgeColor = Colors.transparent;

    if (_mediator.mode == PlaybackMode.snippetMix) {
      final item = _mediator.snippetHandler.currentItem;
      modeLabel = 'DJ MIX: ${item.segment.name} (${item.currentLoop}/${item.loopCount})';
      modeBadgeColor = const Color(0xFFFA2D48);
    } else if (_mediator.mode == PlaybackMode.aiRadio) {
      modeLabel = 'RADIO IA: ${_mediator.radioHandler.activeStation?.name ?? "En vivo"}';
      modeBadgeColor = const Color(0xFF00FFC6);
    }

    final song = _mediator.currentSong;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openFullPlayer,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _mediator.mode == PlaybackMode.snippetMix
                        ? const Color(0xFFFA2D48).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (modeLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: modeBadgeColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              modeLabel,
                              style: TextStyle(color: modeBadgeColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [song.coverColor, song.secondaryColor]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(song.coverIcon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _mediator.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () => _mediator.notify(PlaybackEvent.playPauseToggled),
                        ),
                        IconButton(
                          icon: const Icon(Icons.fast_forward_rounded, color: Colors.white70, size: 26),
                          onPressed: () => _mediator.notify(PlaybackEvent.nextRequested),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA DE NAVEGACIÓN FLOTANTE MODERNA (FLOATING PILL DOCK)
  // ---------------------------------------------------------------------------
  Widget _buildAppleMusicTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF14141A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFA2D48).withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabItem(0, Icons.play_circle_fill_rounded, 'Escuchar'),
                  _buildTabItem(1, Icons.tune_rounded, 'DJ Mix'),
                  _buildTabItem(2, Icons.podcasts_rounded, 'Radio IA'),
                  _buildTabItem(3, Icons.library_music_rounded, 'Biblioteca'),
                  _buildTabItem(4, Icons.search_rounded, 'Buscar'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    const activeColor = Color(0xFFFA2D48);

    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 23,
              color: isSelected ? activeColor : Colors.white38,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? activeColor : Colors.white38,
                letterSpacing: isSelected ? 0.2 : 0.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPRODUCTOR PANTALLA COMPLETA
  // ---------------------------------------------------------------------------
  void _openFullPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ListenableBuilder(
          listenable: _mediator,
          builder: (context, _) {
            final song = _mediator.currentSong;
            final isFavorite = _mediator.queueHandler.favoriteSongIds.contains(song.id);
            final remainingSeconds =
                (song.durationSeconds - _mediator.currentProgressSeconds).clamp(0, 9999).toInt();

            String formatTime(int totalSecs) {
              final mins = totalSecs ~/ 60;
              final secs = totalSecs % 60;
              return '$mins:${secs.toString().padLeft(2, '0')}';
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.94,
              decoration: BoxDecoration(
                color: const Color(0xFF18181C),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: song.coverColor.withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -100,
                    right: -50,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: song.coverColor.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: const SizedBox.expand()),

                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 40,
                                height: 5,
                                margin: const EdgeInsets.only(top: 8, bottom: 8),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.white70),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  Text(
                                    _mediator.mode == PlaybackMode.snippetMix
                                        ? 'DJ MIX (BUCLE ACTIVO)'
                                        : _mediator.mode == PlaybackMode.aiRadio
                                            ? 'RADIO IA CON LOCUTOR'
                                            : 'REPRODUCIENDO',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      letterSpacing: 1.6,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFA2D48),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
                                    onPressed: () => _showInfoSnackBar('Menú ampliado del reproductor próximamente.'),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [song.coverColor, song.secondaryColor]),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: song.coverColor.withValues(alpha: 0.55),
                                        blurRadius: 35,
                                        offset: const Offset(0, 18),
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(song.coverIcon, size: 110, color: Colors.white),
                                ),
                              ),
                            ),
                          ),

                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${song.artist} • ${song.bpm} BPM',
                                          style: const TextStyle(fontSize: 16, color: Colors.white60),
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                      color: isFavorite ? const Color(0xFFFA2D48) : Colors.white54,
                                      size: 30,
                                    ),
                                    onPressed: () => _mediator.notify(PlaybackEvent.favoriteToggled, payload: song.id),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: _mediator.currentProgressSeconds.clamp(0.0, song.durationSeconds.toDouble()),
                                  min: 0.0,
                                  max: song.durationSeconds.toDouble(),
                                  onChanged: (val) {
                                    _mediator.notify(PlaybackEvent.progressSeeked, payload: val);
                                  },
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatTime(_mediator.currentProgressSeconds.toInt()),
                                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                                    ),
                                    Text(
                                      '-${formatTime(remainingSeconds)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.shuffle_rounded,
                                      color: _mediator.isShuffleEnabled
                                          ? const Color(0xFFFA2D48)
                                          : Colors.white38,
                                      size: 26,
                                    ),
                                    onPressed: () => _mediator.notify(PlaybackEvent.toggleShuffle),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 42),
                                    onPressed: () => _mediator.notify(PlaybackEvent.previousRequested),
                                  ),
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: IconButton(
                                      icon: Icon(
                                        _mediator.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        size: 46,
                                        color: Colors.black,
                                      ),
                                      onPressed: () => _mediator.notify(PlaybackEvent.playPauseToggled),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 42),
                                    onPressed: () => _mediator.notify(PlaybackEvent.nextRequested),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _mediator.repeatMode == RepeatMode.one
                                          ? Icons.repeat_one_rounded
                                          : Icons.repeat_rounded,
                                      color: _mediator.repeatMode == RepeatMode.off
                                          ? Colors.white38
                                          : const Color(0xFFFA2D48),
                                      size: 26,
                                    ),
                                    onPressed: () => _mediator.notify(PlaybackEvent.cycleRepeatMode),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  const Icon(Icons.volume_mute_rounded, color: Colors.white38, size: 20),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                        activeTrackColor: Colors.white54,
                                        inactiveTrackColor: Colors.white12,
                                        thumbColor: Colors.white,
                                      ),
                                      child: Slider(
                                        value: _mediator.volume,
                                        onChanged: (val) {
                                          _mediator.notify(PlaybackEvent.volumeChanged, payload: val);
                                        },
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.volume_up_rounded, color: Colors.white38, size: 20),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
