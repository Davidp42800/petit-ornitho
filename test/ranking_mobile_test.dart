import 'test_paths.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/ranking_choice.dart';

void main() {
 testWidgets('Ranking mobile cards and locked controls', (t) async {
  t.view.physicalSize=const Size(390,1100);t.view.devicePixelRatio=1;
  addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  for(final entry in {'Avenir':testAvenirPath(),'MaterialIcons':testFontPath('MaterialIcons-Regular.otf')}.entries){
   final font=File(entry.value);if(font.existsSync())await (FontLoader(entry.key)..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())))).load();
  }
  final q=Question(Map<String,dynamic>.from((jsonDecode(File('data/editorial/ranking-release/questions.json').readAsStringSync()) as List).first));
  var submissions=0;final boundary=GlobalKey();
  Widget build(bool locked)=>RepaintBoundary(key:boundary,child:MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(fontFamily:'Avenir'),home:Scaffold(body:SafeArea(child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[Text(q.prompt,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),RankingChoice(question:q,locked:locked,onAnswer:(_)=>submissions++)])))))));
  await t.pumpWidget(build(false));
  await t.runAsync(() async { for (final bird in q.data['ranking_birds'] as List) { await precacheImage(AssetImage(bird['photo']['asset']), boundary.currentContext!); } });
  await t.pumpAndSettle();
  await t.runAsync(() async {
   final image=await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
   final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
   File('docs/screenshots/ranking-mobile.png').writeAsBytesSync(bytes!.buffer.asUint8List());image.dispose();
  });
  await t.pumpWidget(build(true));await t.pumpAndSettle();
  expect(t.widget<FilledButton>(find.byKey(const ValueKey('rank-confirm'))).onPressed,isNull);
  expect(submissions,0);expect(t.takeException(),isNull);
 });
}
