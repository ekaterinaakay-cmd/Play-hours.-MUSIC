import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart' show Cover, EmptyState, blue, homeButton, message;
import 'store.dart';
import 'model.dart';

class AuthScreen extends StatefulWidget {
  final MusicStore store;
  const AuthScreen({super.key,required this.store});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController(), name = TextEditingController();
  bool register = false, busy = false;
  String error = '';
  @override
  void dispose() {email.dispose(); password.dispose(); name.dispose(); super.dispose();}
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {busy = true; error = '';});
    try {
      final auth = widget.store.db!.auth;
      if (register) {
        final result = await auth.signUp(email:email.text.trim(),password:password.text,data:{'artist_name':name.text.trim()});
        if (result.session == null) {
          if (mounted) {message(context,'Проверь почту и подтверди адрес, затем войди.'); setState(() => register = false);}
          return;
        }
      } else {await auth.signInWithPassword(email:email.text.trim(),password:password.text);}
      await widget.store.refreshUser();
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {if (mounted) setState(() => error = 'Не удалось войти. Проверь интернет и повтори.');}
    finally {if (mounted) setState(() => busy = false);}
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar:AppBar(title:Text(register ? 'Создать аккаунт' : 'Войти'),actions:[homeButton(context)]),
    body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:ListView(padding:const EdgeInsets.all(24),children:[
      Center(child:ClipRRect(borderRadius:BorderRadius.circular(26),child:Image.asset('assets/app-icon.jpg',width:110,height:110))),
      const SizedBox(height:24),const Text('Твоя музыка. Твой профиль.',textAlign:TextAlign.center,style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:30),Form(key:form,child:Column(children:[
        if(register)...[TextFormField(controller:name,maxLength:60,decoration:const InputDecoration(labelText:'Имя артиста'),validator:(v) => (v??'').trim().isEmpty ? 'Укажи имя артиста' : null),const SizedBox(height:14)],
        TextFormField(controller:email,keyboardType:TextInputType.emailAddress,autocorrect:false,decoration:const InputDecoration(labelText:'Email'),validator:(v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim()??'') ? null : 'Укажи email'),
        const SizedBox(height:14),TextFormField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Пароль'),validator:(v) => (v?.length??0) < 8 ? 'Минимум 8 символов' : null),
      ])),
      if(error.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(error,style:const TextStyle(color:Colors.redAccent))),
      const SizedBox(height:24),FilledButton(onPressed:busy ? null : submit,child:Text(busy ? 'Подожди…' : register ? 'Создать аккаунт' : 'Войти')),
      TextButton(onPressed:busy ? null : () => setState(() {register = !register; error = '';}),child:Text(register ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться')),
    ]))));
}

class ProfileScreen extends StatefulWidget {
  final MusicStore store;
  final bool edit;
  const ProfileScreen({super.key,required this.store,this.edit = false});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  late final name = TextEditingController(text:widget.store.artistName);
  late final bio = TextEditingController(text:widget.store.bio);
  bool busy = false;
  final form = GlobalKey<FormState>();
  @override
  void dispose() {name.dispose(); bio.dispose(); super.dispose();}
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable:widget.store,builder:(context,_) => Scaffold(
    appBar:AppBar(title:Text(widget.edit ? 'Настройки профиля' : 'Мой профиль'),actions:[homeButton(context)]),
    body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:620),child:ListView(padding:const EdgeInsets.all(24),children:[
      const Center(child:CircleAvatar(radius:48,child:Icon(Icons.person,size:52))),const SizedBox(height:24),
      if(widget.edit) Form(key:form,child:Column(children:[
        TextFormField(controller:name,maxLength:60,decoration:const InputDecoration(labelText:'Имя артиста'),validator:(v) => (v??'').trim().isEmpty ? 'Укажи имя' : null),
        const SizedBox(height:16),TextFormField(controller:bio,maxLength:500,maxLines:4,decoration:const InputDecoration(labelText:'О себе')),
        const SizedBox(height:22),FilledButton(onPressed:busy ? null : () async {
          if (!form.currentState!.validate()) return;
          setState(() => busy = true);
          try {await widget.store.saveProfile(name.text,bio.text); if(context.mounted) message(context,'Профиль сохранён');}
          catch (_) {if(context.mounted) message(context,'Не удалось сохранить профиль. Повтори попытку.');}
          finally {if(mounted) setState(() => busy = false);}
        },child:Text(busy ? 'Сохраняем…' : 'Сохранить')),
      ])) else ...[
        Text(widget.store.artistName,textAlign:TextAlign.center,style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),Text(widget.store.bio,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60)),
        const SizedBox(height:24),FilledButton.icon(onPressed:() => Navigator.push(context,MaterialPageRoute(builder:(_) => ProfileScreen(store:widget.store,edit:true))),icon:const Icon(Icons.edit_outlined),label:const Text('Настройки профиля')),
      ],
      const SizedBox(height:28),Text(widget.store.db?.auth.currentUser?.email??'',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white38)),
      TextButton(onPressed:() async {
        try {await widget.store.db!.auth.signOut(); if(context.mounted) Navigator.popUntil(context,(r) => r.isFirst);}
        catch (_) {if(context.mounted) message(context,'Не удалось выйти. Повтори попытку.');}
      },child:const Text('Выйти из аккаунта')),
    ]))),
  ));
}

class UploadScreen extends StatefulWidget {
  final MusicStore store;
  const UploadScreen({super.key,required this.store});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}
class _UploadScreenState extends State<UploadScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), genre = TextEditingController(), lyrics = TextEditingController();
  Uint8List? audio, cover;
  String audioName = '', error = '';
  bool busy = false, picking = false;
  @override
  void dispose() {title.dispose(); genre.dispose(); lyrics.dispose(); super.dispose();}
  Future<void> pick(bool artwork) async {
    setState(() => picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:artwork ? ['png','jpg','jpeg','webp'] : ['mp3']);
      if (result == null) return;
      final file = result.files.single;
      final max = artwork ? 15 * 1024 * 1024 : 50 * 1024 * 1024;
      if (file.size > max) throw FormatException(artwork ? 'Обложка должна быть меньше 15 МБ.' : 'MP3 должен быть меньше 50 МБ.');
      final data = file.bytes ?? await File(file.path!).readAsBytes();
      if (data.isEmpty || data.length > max) throw const FormatException('Пустой или слишком большой файл.');
      if (artwork) {
        if (!mounted) return;
        final cropped = await Navigator.push<Uint8List>(context,MaterialPageRoute(builder:(_) => CropScreen(bytes:data)));
        if (cropped != null && mounted) setState(() => cover = cropped);
      } else {
        // MPEG frames or an ID3 tag; validate the selected bytes, not only the extension.
        final valid = data.length > 3 && ((data[0] == 73 && data[1] == 68 && data[2] == 51) || (data[0] == 255 && (data[1] & 224) == 224));
        if (!valid) throw const FormatException('Выбери настоящий MP3-файл.');
        if(mounted) setState(() {audio = data; audioName = file.name;});
      }
    } on FormatException catch(e) {if(mounted) message(context,e.message);}
    catch (_) {if(mounted) message(context,'Не удалось открыть файл. Выбери другой.');}
    finally {if(mounted) setState(() => picking = false);}
  }
  Future<void> publish() async {
    if(!form.currentState!.validate()) return;
    if(audio == null || cover == null) {message(context,'Выбери MP3 и квадратную обложку.'); return;}
    setState(() {busy = true; error = '';});
    try {
      await widget.store.upload(audio:audio!,cover:cover!,title:title.text,genre:genre.text,lyrics:lyrics.text);
      if(mounted) {message(context,'Трек опубликован'); Navigator.popUntil(context,(r) => r.isFirst);}
    } catch (_) {if(mounted) setState(() => error = 'Не удалось опубликовать. Проверь подключение и повтори.');}
    finally {if(mounted) setState(() => busy = false);}
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop:!busy,child:Scaffold(
    appBar:AppBar(title:const Text('Загрузить трек'),automaticallyImplyLeading:!busy,actions:[if(!busy) homeButton(context)]),
    body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:620),child:ListView(padding:const EdgeInsets.all(24),children:[
      Center(child:SizedBox(width:240,height:240,child:InkWell(onTap:busy || picking ? null : () => pick(true),borderRadius:BorderRadius.circular(24),child:Container(
        decoration:BoxDecoration(color:const Color(0xff172334),borderRadius:BorderRadius.circular(24),border:Border.all(color:Colors.white12)),
        child:cover == null ? const Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.add_photo_alternate_outlined,size:44,color:blue),SizedBox(height:14),Text('Добавить обложку'),Text('Квадрат 1:1',style:TextStyle(color:Colors.white38))]) : ClipRRect(borderRadius:BorderRadius.circular(24),child:Image.memory(cover!,fit:BoxFit.cover)),
      )))),const SizedBox(height:24),OutlinedButton.icon(onPressed:busy || picking ? null : () => pick(false),icon:const Icon(Icons.audio_file_outlined),label:Text(audioName.isEmpty ? 'Выбрать MP3 · до 50 МБ' : audioName,maxLines:2)),
      const SizedBox(height:24),Form(key:form,child:Column(children:[
        TextFormField(controller:title,enabled:!busy,maxLength:120,decoration:const InputDecoration(labelText:'Название трека'),validator:(v) => (v??'').trim().isEmpty ? 'Укажи название' : null),
        const SizedBox(height:14),TextFormField(controller:genre,enabled:!busy,maxLength:50,decoration:const InputDecoration(labelText:'Жанр',hintText:'Например, Brazilian funk'),validator:(v) => (v??'').trim().isEmpty ? 'Укажи жанр' : null),
        const SizedBox(height:14),TextFormField(controller:lyrics,enabled:!busy,maxLength:20000,minLines:4,maxLines:10,decoration:const InputDecoration(labelText:'Текст песни',hintText:'Можно оставить пустым для инструментального трека')),
      ])),Text('Артист: ${widget.store.artistName}',style:const TextStyle(color:Colors.white60)),
      const SizedBox(height:12),const Text('Опубликованный трек и обложка будут доступны всем.',style:TextStyle(color:Colors.white38)),
      if(error.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(error,style:const TextStyle(color:Colors.redAccent))),
      const SizedBox(height:24),FilledButton.icon(onPressed:busy || picking ? null : publish,icon:const Icon(Icons.cloud_upload_outlined),label:Text(busy ? 'Публикуем… не закрывай приложение' : 'Опубликовать трек')),
      if(busy) const Padding(padding:EdgeInsets.only(top:16),child:LinearProgressIndicator()),
    ]))),
  ));
}

class CropScreen extends StatefulWidget {
  final Uint8List bytes;
  const CropScreen({super.key,required this.bytes});
  @override
  State<CropScreen> createState() => _CropScreenState();
}
class _CropScreenState extends State<CropScreen> {
  double x = 0.5, y = 0.5, zoom = 1;
  bool busy = false;
  Future<void> crop() async {
    setState(() => busy = true);
    try {
      final decoded = img.decodeImage(widget.bytes);
      if(decoded == null) throw const FormatException();
      final oriented = img.bakeOrientation(decoded);
      final side = (math.min(oriented.width,oriented.height) / zoom).round().clamp(1,math.min(oriented.width,oriented.height)).toInt();
      final cropped = img.copyCrop(oriented,x:((oriented.width-side)*x).round(),y:((oriented.height-side)*y).round(),width:side,height:side);
      final output = img.encodeJpg(img.copyResize(cropped,width:1024,height:1024),quality:90);
      if(mounted) Navigator.pop(context,Uint8List.fromList(output));
    } catch (_) {if(mounted) message(context,'Не удалось обработать картинку. Попробуй JPG или PNG.');}
    finally {if(mounted) setState(() => busy = false);}
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar:AppBar(title:const Text('Квадратная обложка'),actions:[homeButton(context)]),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:600),child:ListView(padding:const EdgeInsets.all(24),children:[
    const Text('В треке будет видна только область внутри квадрата.',style:TextStyle(color:Colors.white60)),const SizedBox(height:20),
    AspectRatio(aspectRatio:1,child:ClipRect(child:LayoutBuilder(builder:(context,box) => OverflowBox(maxWidth:box.maxWidth*zoom,maxHeight:box.maxHeight*zoom,
      alignment:Alignment(x*2-1,y*2-1),child:SizedBox(width:box.maxWidth*zoom,height:box.maxHeight*zoom,child:Image.memory(widget.bytes,fit:BoxFit.cover,alignment:Alignment(x*2-1,y*2-1))))))),
    const SizedBox(height:20),const Text('Положение по горизонтали'),Slider(value:x,onChanged:busy ? null : (v) => setState(() => x = v)),
    const Text('Положение по вертикали'),Slider(value:y,onChanged:busy ? null : (v) => setState(() => y = v)),
    const Text('Масштаб'),Slider(value:zoom,min:1,max:3,onChanged:busy ? null : (v) => setState(() => zoom = v)),
    FilledButton(onPressed:busy ? null : crop,child:Text(busy ? 'Обработка…' : 'Использовать обложку')),
  ]))));
}

class PlayerScreen extends StatefulWidget {
  final MusicStore store;
  const PlayerScreen({super.key,required this.store});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}
class _PlayerScreenState extends State<PlayerScreen> {
  bool liked = false, busy = false;
  int likes = 0;
  String? loadedId;
  MusicStore get s => widget.store;
  @override
  void initState() {super.initState(); s.addListener(changed); changed();}
  @override
  void dispose() {s.removeListener(changed); super.dispose();}
  void changed() {if(loadedId != s.current?.id) {loadedId = s.current?.id; liked = false; likes = 0; refreshLikes();}}
  Future<void> refreshLikes() async {
    final id = s.current?.id;
    if(id == null || s.db == null) return;
    try {
      final count = await s.db!.from('likes').count().eq('track_id',id);
      final row = s.uid == null ? null : await s.db!.from('likes').select('user_id').eq('track_id',id).eq('user_id',s.uid!).maybeSingle();
      if(mounted && s.current?.id == id) setState(() {likes = count; liked = row != null;});
    } catch (_) {}
  }
  Future<bool> needLogin() async {
    if(!s.signedIn) await Navigator.push(context,MaterialPageRoute(builder:(_) => AuthScreen(store:s)));
    return mounted && s.signedIn;
  }
  Future<void> like() async {
    if(!await needLogin() || busy) return;
    final id = s.current!.id;
    setState(() => busy = true);
    try {
      if(liked) {await s.db!.from('likes').delete().eq('track_id',id).eq('user_id',s.uid!);}
      else {await s.db!.from('likes').upsert({'track_id':id,'user_id':s.uid!});}
      await refreshLikes();
    } catch (_) {if(mounted) message(context,'Не удалось изменить лайк. Попробуй ещё раз.');}
    finally {if(mounted) setState(() => busy = false);}
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable:s,builder:(context,_) {
    final t = s.current;
    if(t == null) return Scaffold(appBar:AppBar(actions:[homeButton(context)]),body:const EmptyState(icon:Icons.music_note,title:'Выбери трек',text:'Открой музыку на главной странице.'));
    final total = s.duration.inMilliseconds / 1000;
    return Scaffold(appBar:AppBar(title:const Text('Сейчас играет',style:TextStyle(fontSize:16)),actions:[homeButton(context),
      if(t.ownerId == s.uid) IconButton(tooltip:'Удалить мой трек',icon:const Icon(Icons.delete_outline),onPressed:() async {
        final confirmed = await showDialog<bool>(context:context,builder:(c) => AlertDialog(title:const Text('Удалить трек?'),content:Text('«${t.title}» исчезнет из общего каталога.'),actions:[TextButton(onPressed:() => Navigator.pop(c,false),child:const Text('Отмена')),TextButton(onPressed:() => Navigator.pop(c,true),child:const Text('Удалить'))]));
        if(confirmed != true) return;
        try {await s.removeTrack(t); if(context.mounted) Navigator.pop(context);}
        catch (_) {if(context.mounted) message(context,'Не удалось удалить трек.');}
      }),
    ]),body:Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xff162b41),Color(0xff080b12)])),
      child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:680),child:ListView(padding:const EdgeInsets.fromLTRB(26,14,26,28),children:[
        AspectRatio(aspectRatio:1,child:Cover(url:t.coverUrl)),const SizedBox(height:28),Text(t.title,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w800)),
        const SizedBox(height:6),Text(t.artist,style:const TextStyle(fontSize:20,color:Colors.white60)),const SizedBox(height:6),Text(t.genre,style:const TextStyle(color:blue)),
        const SizedBox(height:20),Wrap(spacing:8,runSpacing:8,children:[
          ActionChip(avatar:Icon(liked ? Icons.favorite : Icons.favorite_border,color:liked ? Colors.redAccent : null,size:18),label:Text('$likes'),onPressed:busy ? null : like),
          ActionChip(avatar:const Icon(Icons.format_quote,size:18),label:const Text('Текст'),onPressed:() => showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,builder:(c) => DraggableScrollableSheet(expand:false,initialChildSize:0.65,builder:(c,controller) => ListView(controller:controller,padding:const EdgeInsets.all(24),children:[Text(t.title,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:20),SelectableText(t.lyrics.isEmpty ? 'Артист не добавил текст.' : t.lyrics,style:const TextStyle(fontSize:18,height:1.6))])))),
          ActionChip(avatar:const Icon(Icons.chat_bubble_outline,size:18),label:const Text('Комменты'),onPressed:() => Navigator.push(context,MaterialPageRoute(builder:(_) => CommentsScreen(store:s,track:t)))),
          ActionChip(avatar:const Icon(Icons.ios_share,size:18),label:const Text('Поделиться'),onPressed:() async {
            // Public MP3 URL is a working HTTPS link without an unconfigured deep-link host.
            final text = '${t.title} — ${t.artist}\nPlay-hours music\n${t.audioUrl}';
            try {final box = context.findRenderObject() as RenderBox?;
              await Share.share(text,sharePositionOrigin:box == null ? null : box.localToGlobal(Offset.zero) & box.size);
            } catch (_) {await Clipboard.setData(ClipboardData(text:text)); if(context.mounted) message(context,'Ссылка скопирована');}
          }),
        ]),const SizedBox(height:24),
        Slider(value:(s.position.inMilliseconds/1000).clamp(0,total > 0 ? total : 1).toDouble(),max:total > 0 ? total : 1,onChanged:total > 0 ? s.seek : null),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(formatTime(s.position),style:const TextStyle(color:Colors.white60)),Text(formatTime(s.duration),style:const TextStyle(color:Colors.white60))]),
        const SizedBox(height:18),Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
          IconButton(tooltip:'Предыдущий',iconSize:38,onPressed:() => s.next(step:-1),icon:const Icon(Icons.skip_previous)),
          FilledButton(style:FilledButton.styleFrom(shape:const CircleBorder(),padding:const EdgeInsets.all(20),backgroundColor:Colors.white,foregroundColor:Colors.black),onPressed:s.toggle,child:Icon(s.playing ? Icons.pause : Icons.play_arrow,size:48)),
          IconButton(tooltip:'Следующий',iconSize:38,onPressed:() => s.next(),icon:const Icon(Icons.skip_next)),
          IconButton(tooltip:'Повторять трек',onPressed:() => setState(() => s.repeat = !s.repeat),icon:Icon(Icons.repeat_one,color:s.repeat ? blue : Colors.white38)),
        ]),if(s.error.isNotEmpty) Padding(padding:const EdgeInsets.only(top:20),child:Text(s.error)),
      ]))),
    ));
  });
}

class CommentsScreen extends StatefulWidget {
  final MusicStore store;
  final Track track;
  const CommentsScreen({super.key,required this.store,required this.track});
  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}
class _CommentsScreenState extends State<CommentsScreen> {
  final input = TextEditingController();
  List<Map<String,dynamic>> comments = [];
  bool busy = false, loading = true, hasMore = true;
  String error = '';
  @override
  void initState() {super.initState(); load();}
  @override
  void dispose() {input.dispose(); super.dispose();}
  Future<void> load({bool more = false}) async {
    if(mounted) setState(() {loading = true; error = '';});
    try {
      final start = more ? comments.length : 0;
      final rows = await widget.store.db!.from('comments').select('id,user_id,body,created_at,profiles(artist_name)').eq('track_id',widget.track.id).order('created_at',ascending:false).range(start,start+49);
      if(mounted) setState(() {comments = more ? [...comments,...rows] : rows; hasMore = rows.length == 50;});
    } catch (_) {if(mounted) setState(() => error = 'Не удалось загрузить комментарии.');}
    finally {if(mounted) setState(() => loading = false);}
  }
  Future<void> send() async {
    if(input.text.trim().isEmpty || busy) return;
    if(!widget.store.signedIn) await Navigator.push(context,MaterialPageRoute(builder:(_) => AuthScreen(store:widget.store)));
    if(!mounted || !widget.store.signedIn) return;
    setState(() => busy = true);
    try {
      await widget.store.db!.from('comments').insert({'track_id':widget.track.id,'user_id':widget.store.uid!,'body':input.text.trim()});
      input.clear(); await load();
    } catch (_) {if(mounted) message(context,'Не удалось отправить комментарий.');}
    finally {if(mounted) setState(() => busy = false);}
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar:AppBar(title:const Text('Комментарии'),actions:[homeButton(context)]),body:Column(children:[
    if(loading) const LinearProgressIndicator(),
    if(error.isNotEmpty) TextButton(onPressed:load,child:Text('$error Повторить')),
    Expanded(child:comments.isEmpty && !loading ? const EmptyState(icon:Icons.forum_outlined,title:'Пока тихо',text:'Оставь первый комментарий.') : RefreshIndicator(onRefresh:load,child:ListView.builder(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(16),itemCount:comments.length + (hasMore ? 1 : 0),itemBuilder:(context,i) {
      if(i == comments.length) return TextButton(onPressed:loading ? null : () => load(more:true),child:const Text('Показать ещё'));
      final c = comments[i];
      return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:8,horizontal:4),leading:const CircleAvatar(child:Icon(Icons.person_outline)),
        title:Text(c['profiles']?['artist_name']??'Артист',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(c['body']),
        trailing:c['user_id'] == widget.store.uid ? IconButton(tooltip:'Удалить комментарий',icon:const Icon(Icons.close,size:18),onPressed:() async {
          try {await widget.store.db!.from('comments').delete().eq('id',c['id']); await load();} catch (_) {if(context.mounted) message(context,'Не удалось удалить комментарий.');}
        }) : null);
    }))),
    SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:TextField(controller:input,maxLength:1000,minLines:1,maxLines:4,decoration:const InputDecoration(hintText:'Написать комментарий…'))),const SizedBox(width:10),IconButton.filled(tooltip:'Отправить',onPressed:busy ? null : send,icon:const Icon(Icons.send))]))),
  ]));
}
