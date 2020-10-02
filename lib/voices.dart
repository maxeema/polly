import 'package:polly/objects.dart';

const voices = {
  'es': {
    'M': [
      VoiceToLang("Enrique", "es-ES"), VoiceToLang("Miguel", "es-US"),
    ],
    'F': [
      VoiceToLang("Lucia", "es-ES"), VoiceToLang("Conchita", "es-ES"),
      VoiceToLang("Mia", "es-MX"), VoiceToLang("Penelope", "es-US"),
    ],
    'S': [VoiceToLang("Lupe", "es-US")]
  }
};
const voicesMap = {
  "es-ES": {
    "M": ["Enrique"],
    "F": ["Lucia", "Conchita"]
  },
  "es-MX": {
    "F": ["Mia"]
  },
  "es-US": {
    "F": ["Penélope", "Lupe"],
    "M": ["Miguel"]
  },
};