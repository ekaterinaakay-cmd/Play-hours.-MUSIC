import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'model.dart';
import 'store.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  SupabaseClient? client;
  if (url.startsWith('https://') && key.isNotEmpty) {
    try {await Supabase.initialize(url:url, anonKey:key); client = Supabase.instance.client;} catch (_) {}
  }
  runApp(MusicApp(store:MusicStore(client)));
}

const blue = Color(0xff69c8ff);
final homeKey = GlobalKey<_HomeState>();
class MusicApp extends StatelessWidget {
  final MusicStore store;
  const MusicApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:'Play-hours music', debugShowCheckedModeBanner:false,
    theme:ThemeData(brightness:Brightness.dark, useMaterial3:true,
      scaffoldBackgroundColor:const Color(0xff080b12),
      colorScheme:ColorScheme.fromSeed(seedColor:blue, brightness:Brightness.dark),
      appBarTheme:const AppBarTheme(backgroundColor:Color(0xff080b12), centerTitle:false),
      inputDecorationTheme:InputDecorationTheme(filled:true, fillColor:const Color(0xff171e2b),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(16), borderSide:BorderSide.none)),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size(48,52))),
    ), home:Home(key:homeKey,store:store));
}

class Home extends StatefulWidget {
  final MusicStore store;
  const Home({super.key, required this.store});
  @override
  State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  final search = TextEditingController();
  Timer? debounce;
  bool searching = false;
  MusicStore get s => widget.store;
  @override
  void dispose() {search.dispose(); debounce?.cancel(); super.dispose();}
  Future<void> authThen(VoidCallback action) async {
    if (!s.configured) {message(context,'Сервер ещё не подключён. Инструкция находится в комплекте проекта.'); return;}
    if (!s.signedIn) await Navigator.push(context, MaterialPageRoute(builder:(_) => AuthScreen(store:s)));
    if (mounted && s.signedIn) action();
  }
  void home() {debounce?.cancel(); search.clear(); s.query = ''; s.mine = false; setState(() => searching = false); unawaited(s.load());}
  void openTrack(Track t) {
    unawaited(s.play(t));
    Navigator.push(context, MaterialPageRoute(builder:(_) => PlayerScreen(store:s)));
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable:s, builder:(context,_) => Scaffold(
    appBar:AppBar(title:const Text('Play-hours music',style:TextStyle(fontWeight:FontWeight.w800,fontSize:22)), actions:[
      IconButton(tooltip:'Поиск',icon:const Icon(Icons.search),onPressed:() => setState(() => searching = !searching)),
      PopupMenuButton<String>(tooltip:'Профиль',offset:const Offset(0,52),
        icon:CircleAvatar(radius:18,backgroundColor:const Color(0xff25354e),child:s.artistName.isEmpty ? const Icon(Icons.person_outline,size:21) : Text(s.artistName.characters.first)),
        itemBuilder:(_) => const [PopupMenuItem(value:'mine',child:Text('Мои треки')),PopupMenuItem(value:'upload',child:Text('Загрузить трек')),
          PopupMenuItem(value:'profile',child:Text('Мой профиль')),PopupMenuItem(value:'settings',child:Text('Настройки профиля'))],
        onSelected:(value) => authThen(() {
          if (value == 'mine') {debounce?.cancel(); search.clear(); s.query = ''; s.mine = true; unawaited(s.load());}
          else {Navigator.push(context,MaterialPageRoute(builder:(_) => value == 'upload' ? UploadScreen(store:s) : ProfileScreen(store:s,edit:value == 'settings')));}
        })), const SizedBox(width:8),
    ]),
    body:Column(children:[
      if (searching) Padding(padding:const EdgeInsets.fromLTRB(20,8,20,12),child:TextField(controller:search,autofocus:true,
        decoration:const InputDecoration(hintText:'Название песни, артист или жанр',prefixIcon:Icon(Icons.search)),
        onChanged:(v) {debounce?.cancel(); debounce = Timer(const Duration(milliseconds:350),() {s.query = v; unawaited(s.load());});})),
      Expanded(child:!s.configured ? EmptyState(icon:Icons.cloud_off_outlined,title:'Подключите музыкальный сервер',
        text:'Приложение подготовлено. Общий каталог появится после подключения сервера владельцем.') :
        RefreshIndicator(onRefresh:() => s.load(),child:CustomScrollView(physics:const AlwaysScrollableScrollPhysics(),slivers:[
          SliverPadding(padding:const EdgeInsets.fromLTRB(22,24,22,20),sliver:SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(s.mine ? 'Твоя музыка' : s.query.isNotEmpty ? 'Результаты поиска' : 'Музыка начинается здесь',style:const TextStyle(fontSize:30,fontWeight:FontWeight.w800)),
            const SizedBox(height:8),Text(s.mine ? 'Треки, которые ты опубликовал' : 'Новые звуки. Новые имена.',style:const TextStyle(color:Colors.white54)),
          ]))),
          if (s.error.isNotEmpty) SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[Text(s.error),TextButton(onPressed:() => s.load(),child:const Text('Повторить'))]))),
          if (s.loading && s.tracks.isEmpty) const SliverToBoxAdapter(child:Center(child:CircularProgressIndicator())),
          if (!s.loading && s.tracks.isEmpty && s.error.isEmpty) SliverFillRemaining(hasScrollBody:false,child:EmptyState(icon:Icons.library_music_outlined,
            title:s.query.isNotEmpty ? 'Ничего не найдено' : 'Пока нет треков',text:s.query.isNotEmpty ? 'Попробуй другое название или имя артиста.' : 'Загрузи первый трек и начни свою историю.',
            action:s.query.isEmpty ? FilledButton.icon(onPressed:() => authThen(() => Navigator.push(context,MaterialPageRoute(builder:(_) => UploadScreen(store:s)))),icon:const Icon(Icons.add),label:const Text('Загрузить трек')) : null)),
          SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverLayoutBuilder(builder:(context,constraints) {
            final columns = constraints.crossAxisExtent > 900 ? 5 : constraints.crossAxisExtent > 620 ? 3 : 2;
            return SliverGrid(delegate:SliverChildBuilderDelegate((context,i) {
              final t = s.tracks[i];
              return InkWell(borderRadius:BorderRadius.circular(18),onTap:() => openTrack(t),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                AspectRatio(aspectRatio:1,child:Cover(url:t.coverUrl)),const SizedBox(height:10),
                Text(t.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16)),
                Text(t.artist,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white54)),
              ]));
            },childCount:s.tracks.length),gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:columns,crossAxisSpacing:18,mainAxisSpacing:24,mainAxisExtent:(constraints.crossAxisExtent - (columns - 1) * 18) / columns + 60));
          })),
          if (s.hasMore) SliverToBoxAdapter(child:TextButton(onPressed:s.loading ? null : () => s.load(more:true),child:Text(s.loading ? 'Загрузка…' : 'Показать ещё'))),
          const SliverToBoxAdapter(child:SizedBox(height:24)),
        ]))),
    ]),
    bottomNavigationBar:SafeArea(top:false,child:Column(mainAxisSize:MainAxisSize.min,children:[
      if (s.current != null) Material(color:const Color(0xff182130),child:ListTile(onTap:() => Navigator.push(context,MaterialPageRoute(builder:(_) => PlayerScreen(store:s))),
        leading:SizedBox(width:48,height:48,child:Cover(url:s.current!.coverUrl)),title:Text(s.current!.title,maxLines:1,overflow:TextOverflow.ellipsis),
        subtitle:Text(s.current!.artist,maxLines:1),trailing:IconButton(tooltip:s.playing ? 'Пауза' : 'Воспроизвести',onPressed:s.toggle,icon:Icon(s.playing ? Icons.pause : Icons.play_arrow)))),
      NavigationBar(selectedIndex:s.mine ? 2 : searching ? 1 : 0,onDestinationSelected:(i) {
        if (i == 0) {home();} else if (i == 1) {setState(() => searching = true);} else {authThen(() {s.mine = true; s.query = ''; search.clear(); unawaited(s.load());});}
      },destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Главная'),
        NavigationDestination(icon:Icon(Icons.search),label:'Поиск'),NavigationDestination(icon:Icon(Icons.library_music_outlined),label:'Мои треки')]),
    ])),
  ));
}

class Cover extends StatelessWidget {
  final String url;
  const Cover({super.key,required this.url});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius:BorderRadius.circular(16),child:Image.network(url,fit:BoxFit.cover,width:double.infinity,height:double.infinity,
    errorBuilder:(_,e,st) => Container(color:const Color(0xff18263b),child:const Center(child:Icon(Icons.music_note,size:42,color:blue)))));
}
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title,text;
  final Widget? action;
  const EmptyState({super.key,required this.icon,required this.title,required this.text,this.action});
  @override
  Widget build(BuildContext context) => Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Icon(icon,size:68,color:blue),const SizedBox(height:22),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w700)),
    const SizedBox(height:10),Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white54,height:1.5)),if(action!=null)...[const SizedBox(height:24),action!],
  ])));
}
void message(BuildContext context,String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));
Widget homeButton(BuildContext context) => IconButton(tooltip:'На главную',icon:const Icon(Icons.home_outlined),onPressed:() {homeKey.currentState?.home(); Navigator.popUntil(context,(r) => r.isFirst);} );
