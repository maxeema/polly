import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/src/md5.dart';

//see school/lib/misc/extensions_dart.dart

extension IntExt on int {
  Duration get  ms => Duration(milliseconds: this);
  Duration get sec => Duration(seconds: this);
}

extension DurationExt on Duration {
  Future get delay => Future.delayed(this);
}

extension StringExt on String {
  String fromAssets() => 'assets/$this';

  String repeat(int times, {String separator = ""})
      => List.filled(times, this).join(separator);

  String substringAfter(String str) => substring(indexOf(str) + str.length);
  String substringAfterLast(String str) => substring(lastIndexOf(str) + str.length);
  String substringBefore(String str) => substring(0, indexOf(str));
  String substringBeforeLast(String str) => substring(0, lastIndexOf(str));

  String format(List<String> args) {
    var formatted = this;
    for (var i = 0; i<args.length; i+=2) {
      formatted = formatted.replaceFirst('%${args[i]}%', args[i+1]);
    }
    return formatted;
  }
  String toBase64() => base64.encode(utf8.encode(this));
  String fromBase64() => utf8.decode(base64.decode(this));

  String toMD5() {
    final enc = utf8.encode(this);
    return md5.convert(enc).toString();
  }
}

extension ListExt<T> on List<T> {
  int get lastIndex => length - 1;
  int get size => length;
  void addFirst(T t) => insert(0, t);
  List<T> toUnmodified() => List.unmodifiable(this);
}
extension SetExt<T> on Set<T> {
  int get size => length;
}

extension StringMarkdownLinksExt on String {

  static final markdownLinkRegexp = RegExp("\\[.+?\\]\\s*\\([^\\[]+\\)");
  static final _keyStart = '[', _keyEnd = ']';
  static final _valueStart = '(', _valueEnd = ')';

  String withMarkdownKey() => _withMarkdown(this, _keyStart, _keyEnd);
  String withMarkdownValue() => _withMarkdown(this, _valueStart, _valueEnd);

  static String _withMarkdown(String str, String start, String end) {
    while (markdownLinkRegexp.hasMatch(str)) {
      final match = markdownLinkRegexp.firstMatch(str);
      final sub = str.substring(match.start, match.end);
      str = str.replaceRange(match.start, match.end, sub.substring(sub.lastIndexOf(start)+1, sub.lastIndexOf(end)));
    }
    return str;
  }

}

extension StringCustomExt on String {

  MapEntry<String, String> toMapEntry(String separator) {
    final idx = this.indexOf(separator);
    return MapEntry(this.substring(0, idx).trim(), this.substring(idx+1));
  }

  Map<int, String> splitIndexed(String separator) {
    var idx = 0;
    final entries = this.split(separator).map((e) => MapEntry(idx++, e));
    return LinkedHashMap.fromEntries(entries);
  }

  String removeFirstAndLastChar(String char) {
    var s = this;
    if (s.startsWith(char) && s.endsWith(char)) {
      s = s.substring(1);
      s = s.length == 0 ? s : s.substring(0, s.length - 1);
    }
    return s;
  }

  Future<void> exec(String args, {String workDir, bool printCmd}) async {
    final cmd = 'bash';
    final params = ['-c', '$this $args'];
    if (printCmd ?? false) {
      print("$cmd ${params.join(" ")}");
    }
    Process process;
    try {
      process = await Process.start(cmd, params, workingDirectory: workDir);
      process.stderr.transform(utf8.decoder).listen(print);
      process.stdout.transform(utf8.decoder).listen(print);
    } catch (err) {
      print('execute error: $err');
      exit(-1);
    }
    final code = await process.exitCode;
    if (code != 0) {
      print('exit code $code');
      exit(code);
    }
  }

  langNameToCode() {
    final s = this.toLowerCase();
    switch (s) {
      case "dutch":   return 'nl';
      case "english": return 'en';
      case "russian": return 'ru';
      case "spanish-ca": return 'es';
    }
    throw "Unknown lang: $s";
  }

  String langCodeToName() {
    final s = this.toLowerCase();
    switch (s) {
      case 'nl': return 'dutch';
      case 'en': return 'english';
      case 'ru': return 'russian';
      case 'es': return 'spanish-ca';
    }
    throw "Unknown lang: $s";
  }

  String langCodeToSphinxDic() {
    final lang = this.toLowerCase();
    switch (lang) {
      case 'en': return 'cmudict-en-us.dict';
      case 'nl':
      case 'es': return 'voxforge_${lang}_sphinx.dic';
    }
    throw "Unknown lang: $lang";
  }

  toFsg() => this.toLowerCase()
      .replaceAll('-', ' ')
      .replaceAll('…', '. ')
      .replaceAll('’', '\'')
      .replaceAll(RegExp(r'\.{3}'), '. ')
      .replaceAll(RegExp(r'[\?!\.,()":¿¡]'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

}

extension MapExt on Map<String, dynamic> {
  
  saveTo(File file) => file.writeAsStringSync(jsonEncode(this));

  bool containsAll(List<String> whichKeys) {
    for (final key in whichKeys) {
      if (!containsKey(key))
        return false;
    }
    return true;
  }
  
}
