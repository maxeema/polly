
import 'dart:convert';
import 'dart:io';

import 'package:polly/extensions.dart';
import 'package:polly/objects.dart';
import 'package:polly/voices.dart';

// dart bin/polly.dart in/es.csv

const _polly = "polly"
  " synthesize-speech"
//  " --engine neural" // standard or neural
  " --language-code %lang%" //es-ES
  " --voice-id %speaker%" //Enrique
  " --text \"%phrase%\""
  " --output-format mp3"
  " \"%file%\"";

const _ext = 'csv', _sep = ';';

const _db = '../media/audios';

const TAG = "Polly";

main(List<String> args) async {
  print('[$TAG] starts with args: $args');
  await "rm".exec("-rf build/");
  if (args.isEmpty || !args.first.endsWith(_ext))
    throw 'Missing required input file param!';
  //
  final input = args[0];
  final lang = input.substringAfterLast('/').substringBefore('.');
  //
  // await "mkdir".exec("-p db/$lang/");
  final dbJsonFile = File('$_db/$lang.json');
  final dbJson = dbJsonFile.existsSync()
      ? jsonDecode(dbJsonFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
//  print('indexJson: $dbJson');
  //
  var lineIdx = 0;
  Map<String, int> columns;
  final downloaded = <String, String>{};
  final small = <String, int>{};
  final index = <String, String>{};
  try {
    for (final line in File(input).readAsLinesSync()) {
      if (lineIdx++ == 0) {
        columns = line.splitIndexed(_sep).map((idx, value) =>
            MapEntry(
                value.removeFirstAndLastChar('"').trim().toLowerCase(), idx));
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
      final filename = '$phraseMd5-polly-${voiceToLang.lang}-${voiceToLang
          .voice}.mp3';
      final file = File('$_db/$lang/$filename');
      index[file.path] = phrase;
      if (file.existsSync() && file.lengthSync() > 1000) {
        // downloaded already
        dbJson[phraseMd5] = phrase;
      } else {
        if (dbJson.containsKey(phraseMd5) && dbJson[phraseMd5] != phrase) {
          throw "Got '$phraseMd5' hash collision for '$phrase'";
        }
        await "aws".exec(
            _polly.format([
              'lang', voiceToLang.lang,
              'speaker', voiceToLang.voice,
              'phrase', phrase.replaceAll("\"", "\\\""),
              'file', file.path
            ]),
            printCmd: true
        );
        final fileSize = file.lengthSync();
        if (fileSize < 500)
          throw "Corrupted download!"
              "\nfile: $filename"
              "\nbytes: $fileSize"
              "\nphrase: $phrase"
              "\nTry to re-run Polly download script or handle the cause manually!";
        //
        try {
          await "gsutil".exec("-m cp ${file.path} gs://heart-school-europe/audio/$lang");
        } catch (e) {
          // If failed to store just downloaded mp3 at Firebase
          // then delete local copy to keep files synced locally and remotely
          file.delete();
          rethrow;
        }
        //
        if (fileSize < 2000)
          small[filename] = fileSize;
        downloaded[filename] = phrase;
        //
        await 300.ms.delay;
      }
      dbJson[phraseMd5] = phrase;
    }
  } catch (e) {
    // let finally block to be executed before printing stacktrace
    await 2000.ms.delay;
    rethrow;
  } finally {
    await "gsutil".exec("-m cp -r ${dbJsonFile.path} gs://heart-school.appspot.com/audio");
    dbJson.saveTo(dbJsonFile);
    if (downloaded.isNotEmpty) {
      print('> New downloads:');
      downloaded.forEach((filename, phrase) {
        print("   $filename -> $phrase");
      });
    } else {
      print('> No new downloads.');
    }
    if (small.isNotEmpty) {
      print('> Too small files (listen to them, are they ok?):');
      small.forEach((filename, size) {
        print("   $filename -> $size bytes");
      });
    }
  }
  //
  await "mkdir".exec("-p build/");
  index.saveTo(File("build/$lang.json"));
  print("> Total unique phrases and mp3 for this call: ${index.length}. See 'build/$lang.json'");
  print("> Total unique mp3 in db for the '$lang' lang: ${index.length}. See '$_db/$lang/*.mp3' and '$_db/$lang.json'.");
  //
  print('[$TAG] finished successfully');
}

