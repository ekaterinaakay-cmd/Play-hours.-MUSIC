import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'model.dart';

class MusicStore extends ChangeNotifier {
  final SupabaseClient? db;
  final AudioPlayer player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<Track> tracks = [];
  Track? current;
  Duration position = Duration.zero, duration = Duration.zero;
  bool playing = false, loading = false, repeat = false, hasMore = false;
  String artistName = '', bio = '', query = '', error = '';
  bool mine = false;
  int _request = 0;
  bool _disposed = false;
  MusicStore(this.db) {
    _subscriptions.add(player.onPositionChanged.listen((p) {position = p; notifyListeners();}));
    _subscriptions.add(player.onDurationChanged.listen((d) {duration = d; notifyListeners();}));
    _subscriptions.add(player.onPlayerStateChanged.listen((s) {playing = s == PlayerState.playing; notifyListeners();}));
    _subscriptions.add(player.onPlayerComplete.listen((_) {unawaited(completed());}));
    if (db != null) {
      _subscriptions.add(db!.auth.onAuthStateChange.listen((_) {unawaited(refreshUser());}));
      unawaited(refreshUser());
    }
  }
  bool get configured => db != null;
  String? get uid => db?.auth.currentUser?.id;
  bool get signedIn => uid != null;
  @override
  void notifyListeners() {if (!_disposed) super.notifyListeners();}
  Future<void> refreshUser() async {
    try {
      final identity = uid;
      if (identity == null) {artistName = ''; bio = ''; mine = false;}
      else {
        final row = await db!.from('profiles').select().eq('id', identity).maybeSingle();
        if (uid != identity) return;
        artistName = row?['artist_name'] ?? '';
        bio = row?['bio'] ?? '';
      }
      await load();
    } catch (_) {error = 'Не удалось загрузить профиль. Проверьте интернет.'; notifyListeners();}
  }
  Future<void> load({bool more = false}) async {
    if (db == null) return;
    if (more && loading) return;
    final request = ++_request;
    final offset = more ? tracks.length : 0;
    loading = true; error = ''; notifyListeners();
    try {
      final rows = await db!.rpc('catalog', params: {
        'search_text': query, 'only_mine': mine, 'page_offset': offset,
      });
      if (request != _request) return;
      final incoming = (rows as List).map((r) {
        final map = Map<String, dynamic>.from(r);
        map['profiles'] = {'artist_name': map['artist_name']};
        return Track.fromJson(map);
      }).toList();
      tracks = more ? [...tracks, ...incoming] : incoming;
      hasMore = incoming.length == 50;
    } catch (_) {if (request == _request) error = 'Не удалось загрузить треки. Проверьте интернет и повторите.';}
    finally {if (request == _request) {loading = false; notifyListeners();}}
  }
  Future<void> saveProfile(String name, String about) async {
    if (!signedIn) throw StateError('Войдите в аккаунт.');
    await db!.from('profiles').update({'artist_name': name.trim(), 'bio': about.trim()}).eq('id', uid!);
    artistName = name.trim(); bio = about.trim();
    // The current player also reflects an artist-name change.
    if (current?.ownerId == uid) {
      final t = current!;
      current = Track(id:t.id, ownerId:t.ownerId, title:t.title, artist:artistName,
        genre:t.genre, lyrics:t.lyrics, coverUrl:t.coverUrl, audioUrl:t.audioUrl);
    }
    await load();
  }
  Future<void> upload({required Uint8List audio, required Uint8List cover,
      required String title, required String genre, required String lyrics}) async {
    final owner = uid;
    if (owner == null) throw StateError('Войдите в аккаунт.');
    final id = const Uuid().v4();
    final audioPath = '$owner/$id.mp3', coverPath = '$owner/$id.jpg';
    final storage = db!.storage.from('music');
    final uploaded = <String>[];
    try {
      await storage.uploadBinary(audioPath, audio, fileOptions: const FileOptions(contentType:'audio/mpeg'));
      uploaded.add(audioPath);
      await storage.uploadBinary(coverPath, cover, fileOptions: const FileOptions(contentType:'image/jpeg'));
      uploaded.add(coverPath);
      await db!.from('tracks').insert({'id':id, 'owner_id':owner, 'title':title.trim(),
        'genre':genre.trim(), 'lyrics':lyrics.trim(), 'audio_path':audioPath, 'cover_path':coverPath,
        'audio_url':storage.getPublicUrl(audioPath), 'cover_url':storage.getPublicUrl(coverPath)});
    } catch (_) {
      if (uploaded.isNotEmpty) {try {await storage.remove(uploaded);} catch (_) {}}
      rethrow;
    }
    mine = false; query = ''; await load();
  }
  Future<void> removeTrack(Track t) async {
    if (t.ownerId != uid) throw StateError('Недостаточно прав.');
    if (current?.id == t.id) {await player.stop(); current = null;}
    await db!.from('tracks').delete().eq('id', t.id);
    // If a transfer fails, metadata is already hidden. Owner can retry cleanup.
    try {await db!.storage.from('music').remove(['${t.ownerId}/${t.id}.mp3','${t.ownerId}/${t.id}.jpg']);} catch (_) {}
    await load();
  }
  Future<void> play(Track t) async {
    try {
      if (current?.id == t.id) {if (!playing) await player.resume(); return;}
      current = t; position = Duration.zero; duration = Duration.zero; notifyListeners();
      await player.play(UrlSource(t.audioUrl));
    } catch (_) {error = 'Не удалось воспроизвести MP3. Проверьте подключение.'; notifyListeners();}
  }
  Future<void> toggle() async {
    try {if (playing) {await player.pause();} else if (current != null) {
      if (position >= duration && duration > Duration.zero) await player.seek(Duration.zero);
      await player.resume();
    }} catch (_) {error = 'Не удалось запустить плеер.'; notifyListeners();}
  }
  Future<void> completed() async {
    if (repeat && current != null) {
      try {await player.play(UrlSource(current!.audioUrl));} catch (_) {error = 'Не удалось повторить трек.'; notifyListeners();}
    } else {await next();}
  }
  Future<void> next({int step = 1}) async {
    if (current == null) return;
    final i = tracks.indexWhere((t) => t.id == current!.id);
    if (i >= 0 && i + step >= 0 && i + step < tracks.length) await play(tracks[i + step]);
  }
  Future<void> seek(double seconds) async {
    try {await player.seek(Duration(milliseconds:(seconds * 1000).round()));} catch (_) {}
  }
  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {s.cancel();}
    player.dispose(); super.dispose();
  }
}
