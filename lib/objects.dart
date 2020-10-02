
class VoiceToLang {

  final String voice, lang;

  const VoiceToLang(this.voice, this.lang);

}

class Entry {

  final String party, sex, phrase;

  Entry.of(Map<int, String> map, Map<String, int> columns)
      : this.party  = map[columns['party']],
        this.sex    = map[columns['sex']],
        this.phrase = map[columns['phrase']];

  @override String toString() => '$party - $sex - $phrase';

}
