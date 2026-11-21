import 'dart:io';

// Use the installed Flutter SDK on local machines and CI runners alike.
String testFontPath(String filename) {
  var directory = File(Platform.resolvedExecutable).parent;
  final configured = Platform.environment['FLUTTER_ROOT'];
  if (configured != null) directory = Directory(configured);
  while (true) {
    final file = File('${directory.path}/bin/cache/artifacts/material_fonts/$filename');
    if (file.existsSync()) return file.path;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Flutter test font not found: $filename');
    }
    directory = parent;
  }
}

String testAvenirPath() {
  final native = File('/System/Library/Fonts/Avenir Next.ttc');
  return native.existsSync() ? native.path : testFontPath('Roboto-Regular.ttf');
}
