import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/ui/mystery_photo_hint.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';
import 'package:petit_ornitho/ui/pepi_hint_button.dart';
void main(){
 testWidgets('Photo remains hidden until assistance is saved; no name exposed',(t)async{
  final save=Completer<bool>();
  await t.pumpWidget(MaterialApp(home:Scaffold(body:MysteryPhotoHint(species:'robin',photo:{'asset':'assets/birds/robin.jpg'},busy:false,beforeHint:()=>save.future,onSource:(){}))));
  expect(find.byType(BirdPhoto),findsNothing);
  await t.tap(find.text('Découvrir la photo'));await t.pump();
  expect(find.byType(BirdPhoto),findsNothing);
  await t.runAsync(() async {
    await precacheImage(const AssetImage('assets/birds/robin.jpg'), t.element(find.byType(MysteryPhotoHint)));
  });
  save.complete(true);await t.pumpAndSettle();
  expect(find.byType(BirdPhoto),findsOneWidget);
  expect(find.text('Rougegorge familier'),findsNothing);
  await t.pump(const Duration(seconds: 3));await t.pumpAndSettle();
  expect(find.byType(BirdPhoto), findsNothing);
  expect(t.widget<PepiHintButton>(find.byType(PepiHintButton)).onPressed, isNotNull);
 });
 testWidgets('Missing photo has an explicit unavailable state',(t)async{
  await t.pumpWidget(MaterialApp(home:Scaffold(body:MysteryPhotoHint(species:'missing',photo:null,busy:false,beforeHint:()async=>true,onSource:(){}))));
  expect(t.widget<PepiHintButton>(find.byType(PepiHintButton)).onPressed,isNull);
  expect(find.textContaining('pas encore disponible'),findsOneWidget);
 });
}
