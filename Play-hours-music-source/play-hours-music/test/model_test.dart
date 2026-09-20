import 'package:flutter_test/flutter_test.dart';
import 'package:play_hours_music/model.dart';
void main() {
  const track = Track(id:'1', ownerId:'2', title:'Тёплый вечер', artist:'Тимур', genre:'Funk', lyrics:'', coverUrl:'', audioUrl:'');
  test('search handles Cyrillic, ё, artist and small typos', () {
    expect(matchesTrack(track,'теплый'),true);
    expect(matchesTrack(track,'тимур'),true);
    expect(matchesTrack(track,'вечр'),true);
    expect(matchesTrack(track,'несуществующее'),false);
    expect(matchesTrack(track,''),true);
  });
  test('time formatting preserves minute and second boundaries', () {
    expect(formatTime(const Duration(seconds:61)),'1:01');
    expect(formatTime(Duration.zero),'0:00');
  });
}
