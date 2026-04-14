import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum JustificationFont {
  digitalKhatt('digitalkhatt.otf');

  const JustificationFont(this.fileName);

  final String fileName;

  String get _assetKey => 'packages/arabic_text_justification/assets/$fileName';

  Future<String> load() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$fileName');
    if (!await file.exists()) {
      final data = await rootBundle.load(_assetKey);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }
}
