import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/picture_choice_board.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

void main() {
 testWidgets('Four-photo mission rendered with real images', (t) async {
  t.view.physicalSize=const Size(600,1000);t.view.devicePixelRatio=1;
  addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  for(final entry in {'Avenir':'/System/Library/Fonts/Avenir Next.ttc','MaterialIcons':'/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'}.entries){
   final font=File(entry.value);if(font.existsSync())await (FontLoader(entry.key)..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())))).load();
  }
  final q=Question(Map<String,dynamic>.from((jsonDecode(File('data/editorial/picture-missions/questions.json').readAsStringSync()) as List).firstWhere((q)=>q['id']=='picture_v2_5_inat-187660947')));
  var submissions=0;final boundary=GlobalKey();
  Widget build(bool locked)=>RepaintBoundary(key:boundary,child:MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(fontFamily:'Avenir'),home:PictureChoiceBoard(question:q,feedback:null,busy:locked,step:1,total:6,onAnswer:(_)=>submissions++,onNext:(){})));
  await t.pumpWidget(build(false));
  await t.runAsync(() async { for (final photo in q.data['image_options'] as List) { await precacheImage(AssetImage(bundledBirdAsset(photo['asset'])), boundary.currentContext!); } });
  await t.pumpAndSettle();
  await t.runAsync(() async {
   final image=await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
   final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
   File('docs/screenshots/picture-mission.png').writeAsBytesSync(bytes!.buffer.asUint8List());image.dispose();
  });
  await t.pumpWidget(build(true));await t.pumpAndSettle();
  await t.tap(find.text('Photo 1'));expect(find.byType(BirdPhoto),findsNWidgets(4));
  expect(submissions,0);expect(t.takeException(),isNull);
 });
}
