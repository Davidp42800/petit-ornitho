import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/picture_choice_board.dart';

class GuestStore extends GameStore {
 GuestStore(super.prefs,super.content,super.media,{super.photoCatalog,super.speciesCatalog,super.progression});
 @override String get identity=>'guest';
}
void main(){
 testWidgets('Image choices stay unlocked, answer matches photo, feedback reveals names',(tester)async{
  dynamic read(String name)=>jsonDecode(File('assets/data/$name.json').readAsStringSync());
  SharedPreferences.setMockInitialValues({});
  final store=GuestStore(await SharedPreferences.getInstance(),read('content'),[],photoCatalog:read('photo_catalog'),speciesCatalog:read('species_catalog'),progression:read('progression'))..reload();
  final round=store.imageChoiceRound(Random(14));
  expect(round,isNotEmpty);
  for(final q in round){
   final ids=List<String>.from(q.data['option_species']);
   expect(ids.toSet().length,4);
   expect(ids.every(store.speciesAvailable),true);
   expect(ids[q.answer],q.species);
   expect(q.data['image_options'][q.answer]['id'],q.data['photo']['id']);
   for(final image in q.data['image_options']){expect(File(image['asset']).existsSync(),true);}
  }
  final q=round.first;
  int? chosen;
  await tester.pumpWidget(MaterialApp(home:PictureChoiceBoard(question:q,feedback:null,busy:false,step:1,total:round.length,onAnswer:(i)=>chosen=i,onNext:(){})));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Photo 1'));expect(chosen,0);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(MaterialApp(home:PictureChoiceBoard(question:q,feedback:{'choice':q.answer,'correct':true},busy:false,step:1,total:round.length,onAnswer:(i)=>chosen=i,onNext:(){})));
  await tester.pumpAndSettle();
  expect(find.text('✓ ${q.options[q.answer]}'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}
