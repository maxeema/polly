
import 'dart:convert';
import 'dart:io';

import 'package:polly/extensions.dart';
import 'package:polly/objects.dart';
import 'package:polly/voices.dart';

// dart bin/polly.dart in/es.csv

const _delayAfterEachDownload = 100;
const _smallFileThatLessThan = 2500;
const _corruptedDownloadSize = 500;

const _polly = "polly"
  " synthesize-speech"
//  " --engine neural" // standard or neural
  " --language-code %lang%" //es-ES
  " --voice-id %speaker%" //Enrique
  " --text \"%phrase%\""
  " --output-format mp3"
  " \"%file%\"";

const _ext = 'csv', _sep = ';';

const _gs_bucket_url = 'gs://heart-school-europe';

const TAG = "Polly";

main(List<String> args) async {
  print('[$TAG] starts with args: $args');
  await "rm".exec("-rf build/*.txt");
  await "rm".exec("-rf build/*.json");
  if (args.isEmpty || !args.first.endsWith(_ext))
    throw 'Missing required input file param!';
  //
  final input = args[0];
  final lang = input.substringAfterLast('/').substringBefore('.');
  //
  await "mkdir".exec("-p build/$lang");
  //
  final langRemote = '${_gs_bucket_url}/audio/${lang}.json';
  print('downloading... ${langRemote}');
  final langDbOrig = 'build/${lang}-orig.json';
  await "gsutil".exec("-m cp ${langRemote} ${langDbOrig}");
  print("reading... ${langDbOrig}");
  final langDbOrigFile = File(langDbOrig);
  final db = langDbOrigFile.existsSync()
      ? jsonDecode(langDbOrigFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  //
  final indexRemote = '${_gs_bucket_url}/audio/${lang}-index.txt';
  print('downloading... ${indexRemote}');
  final langIndexOrig = 'build/${lang}-index-orig.txt';
  await "gsutil".exec("-m cp ${indexRemote} ${langIndexOrig}");
  print('reading... ${langIndexOrig}');
  final index = File(langIndexOrig).readAsStringSync().split('\n');
  //
  var lineIdx = 0;
  Map<String, int> columns;
  final downloaded = <String, String>{};
  final small = <String, int>{};
  // final index = <String, String>{};
  final neu = <String>{};
  try {
    for (final line in File(input).readAsLinesSync()) {
      if (lineIdx++ == 0) {
        columns = line.splitIndexed(_sep).map((idx, value) =>
            MapEntry(value.removeFirstAndLastChar('"').trim().toLowerCase(), idx));
        // check all required presented
        columns.containsAll(['party', 'sex', 'phrase'])
            ? true : throw "Missing some required columns!";
        print("> columns: $columns");
        continue;
      }
      //
      final entries = line.splitIndexed(_sep).map((idx, value) =>
          MapEntry(idx, value.removeFirstAndLastChar('"').trim()));
      final entry = Entry.of(entries, columns);
      final phrase = entry.phrase.normalizeSpaces();
      final voiceToLang = entry.party == 'S'
          ? voices[lang]['S'][0]
          : voices[lang][entry.sex][entry.party == 'A' ? 0 : 1];
      //
      final phraseMd5 = phrase.toMD5();
      if (db.containsKey(phraseMd5) && db[phraseMd5] != phrase) {
        throw "Got '$phraseMd5' hash collision for '$phrase'";
      }
      db[phraseMd5] = phrase;
      //
      final file = '$phraseMd5-polly-${voiceToLang.lang}-${voiceToLang.voice}.mp3';
      final downloadFile = File('build/${lang}/${file}');
      if (!index.contains(file)) {
        if (downloadFile.existsSync()) {
          if (downloadFile.lengthSync() < _corruptedDownloadSize)
            downloadFile.deleteSync();
        }
        if (!downloadFile.existsSync()) {
          //TODO(speed improvement) consider a multi-threads downloading for the fastest execution
          await "aws".exec(
              _polly.format([
                'lang', voiceToLang.lang,
                'speaker', voiceToLang.voice,
                'phrase', phrase.replaceAll("\"", "\\\""),
                'file', downloadFile.path
              ]),
              printCmd: true
          );
        }
        final fileSize = downloadFile.lengthSync();
        if (fileSize < _corruptedDownloadSize)
          throw "Corrupted download!"
              "\nfile: $file"
              "\nbytes: $fileSize"
              "\nphrase: $phrase"
              "\nTry to re-run Polly download script or handle the cause manually!";
        if (fileSize < _smallFileThatLessThan)
          small[file] = fileSize;
        //
        //map[phrase][mapSex] = voice;
        neu.add(downloadFile.path);
        index.add(file);
        downloaded[file] = phrase;
        print(' - ${downloadFile.lengthSync()}: ${file}');
        //
        await _delayAfterEachDownload.ms.delay;
      }
    }
    //
    if (!neu.isNotEmpty) {
      print('no new downloads');
      return;
    }
    //sync new downloads to Firebase Storage
    final neuLangList = '${lang}-neu.txt';
    await File('build/${neuLangList}').writeAsString(neu.join('\n'));
    print('syncing... all mp3 from ${neuLangList}');
    await "cat".exec('build/${neuLangList} | gsutil -m cp -I ${_gs_bucket_url}/audio/${lang}');
    print('new downloads:\n ${neu.join('\n ')}');
    //
    if (small.isNotEmpty) {
      print('> Too small files (listen to them, are they ok?)');
      small.forEach((filename, size) {
        print("   $filename -> $size bytes");
      });
    }
    // sync db
    final langDb = '$lang.json';
    db.saveTo(File('build/${langDb}'));
    print('syncing... build/${langDb}');
    await "gsutil".exec("-m cp build/${langDb} ${_gs_bucket_url}/audio");
    // sync index
    final langIndex = '${lang}-index.txt';
    await File('build/${langIndex}').writeAsString(index.join('\n'));
    print('syncing... build/${langIndex}');
    await "gsutil".exec("-m cp build/${langIndex} ${_gs_bucket_url}/audio");
    //
    print("> Total unique phrases and mp3 for this call: ${neu.length}. See 'build/$neuLangList'.");
    print("> Total unique mp3 in db for the '$lang' lang: ${index.length}. See 'build/$langIndex' and 'build/$langDb' mapping.");
  } catch (e) {
    // let finally block to be executed before printing stacktrace
    await 2000.ms.delay;
    rethrow;
  }
  //
  print('[$TAG] finished successfully');
}

