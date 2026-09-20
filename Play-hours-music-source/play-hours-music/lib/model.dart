class Track {
  final String id, ownerId, title, artist, genre, lyrics, coverUrl, audioUrl;
  const Track({required this.id, required this.ownerId, required this.title,
    required this.artist, required this.genre, required this.lyrics,
    required this.coverUrl, required this.audioUrl});
  factory Track.fromJson(Map<String, dynamic> row) => Track(
    id: row['id'], ownerId: row['owner_id'], title: row['title'],
    artist: (row['profiles'] as Map?)?['artist_name'] ?? 'Артист',
    genre: row['genre'], lyrics: row['lyrics'] ?? '',
    coverUrl: row['cover_url'], audioUrl: row['audio_url']);
}

String normalizeSearch(String value) => value.toLowerCase().replaceAll('ё', 'е').trim();

// All query words must appear in title, artist or genre. A small edit distance
// also tolerates spelling errors in song names, in both Cyrillic and Latin.
int editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = <int>[i];
    for (var j = 1; j <= b.length; j++) {
      final insert = current[j - 1] + 1;
      final delete = previous[j] + 1;
      final replace = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      current.add([insert, delete, replace].reduce((a, b) => a < b ? a : b));
    }
    previous = current;
  }
  return previous.last;
}

bool matchesTrack(Track track, String query) {
  final q = normalizeSearch(query);
  if (q.isEmpty) return true;
  final hay = normalizeSearch('${track.title} ${track.artist} ${track.genre}');
  final words = hay.split(RegExp(r'\s+'));
  return q.split(RegExp(r'\s+')).every((part) => hay.contains(part) ||
    (part.length >= 4 && words.any((word) => editDistance(part, word) <= 1)));
}

String formatTime(Duration time) => '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';
