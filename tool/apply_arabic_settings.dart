import 'dart:io';

void main() {
  final dir = Directory('lib/screens/settings');
  if (!dir.existsSync()) throw StateError('Settings directory not found');
  final files = <File>[
    File('lib/screens/settings_screen.dart'),
    ...dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')),
  ];
  var changed = 0;
  for (final file in files) {
    var source = file.readAsStringSync();
    final original = source;
    final isRootSettings = file.path.endsWith('screens/settings_screen.dart');
    final importPath = isRootSettings ? "../utils/arabic_text.dart" : "../../utils/arabic_text.dart";

    final hasArabicImport = source.contains("utils/arabic_text.dart");
    final hasMaterialImport =
        source.contains("import 'package:flutter/material.dart';") ||
        source.contains('import "package:flutter/material.dart";');

    if (hasMaterialImport) {
      source = source.replaceFirst(
        RegExp(r'''import ['"]package:flutter/material\.dart['"];'''),
        "import 'package:flutter/material.dart' hide Text;",
      );
    } else {
      source =
          "import 'package:flutter/material.dart' hide Text;\n" + source;
    }

    if (!hasArabicImport) {
      source = source.replaceFirst(
        RegExp(r"import 'package:flutter/material.dart' hide Text';\n"),
        "import 'package:flutter/material.dart' hide Text;\nimport '$importPath';\n",
      );
    }

    source = source.replaceAll('const Text(', 'Text(');
    if (source != original) {
      file.writeAsStringSync(source);
      changed++;
    }
  }
  stdout.writeln('Arabic settings transform: $changed files prepared');
}
