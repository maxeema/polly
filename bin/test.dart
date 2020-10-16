
import 'dart:io';

main(List<String> args) async {
  indexFiles('en', '/tmp/1/media/audios');
  indexFiles('ru', '/tmp/1/media/audios');
  indexFiles('nl', '/tmp/1/media/audios');
  indexFiles('es', '/tmp/1/media/audios');
}
indexFiles(String lang, String path) async {
  print('start');
  //
  final ar = <String> {};
  await Directory('$path/$lang/')
      .list()
      .map((file) => file.path.substring(file.path.lastIndexOf('/')+1))
      .forEach(ar.add);
  final res = await File('$path/$lang-index.txt')
      .writeAsString(ar.toList(growable: false).join('\n'));
  print(' > ${res.path}');
  //
  print('finish');
}

