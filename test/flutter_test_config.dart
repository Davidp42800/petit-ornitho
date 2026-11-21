import 'dart:async';
import 'dart:io';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Captures are generated artifacts and are absent in a fresh checkout.
  Directory('docs/screenshots').createSync(recursive: true);
  await testMain();
}
