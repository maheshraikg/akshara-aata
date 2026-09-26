/// Kannada varnamala content: 49 letters (13 swaras + 2 yogavahas + 34 vyanjanas),
/// numerals and kagunita vowel signs.
library;

enum Group { swara, yogavaha, vyanjana }

class Letter {
  const Letter(
    this.ch,
    this.tr,
    this.group,
    this.varga,
    this.word,
    this.wordTr,
    this.emoji,
    this.en, {
    this.start = true,
  });

  final String ch;
  final String tr;
  final Group group;
  final String varga;
  final String word;
  final String wordTr;
  final String emoji;
  final String en;

  /// False when the letter is not the first sound of [word]; the
  /// "which letter does it start with?" game skips those.
  final bool start;
}

class KNumber {
  const KNumber(this.ch, this.n, this.word, this.wordTr);
  final String ch;
  final int n;
  final String word;
  final String wordTr;
}

class VowelSign {
  const VowelSign(this.sign, this.vowel, this.tr);
  final String sign;
  final String vowel;
  final String tr;
}

class Varga {
  const Varga(this.id, this.name, this.en);
  final String id;
  final String name;
  final String en;
}

/// Anything that can be shown on a learning card or traced.
class CardItem {
  const CardItem({
    required this.ch,
    required this.say,
    required this.sayRoman,
    required this.word,
    required this.wordTr,
    required this.label,
    this.emoji,
    this.en,
    this.count,
    this.color = CardColor.red,
  });

  final String ch;
  final String say;
  final String sayRoman;
  final String word;
  final String wordTr;
  final String label;
  final String? emoji;
  final String? en;
  final int? count;
  final CardColor color;

  factory CardItem.letter(Letter l) => CardItem(
    ch: l.ch,
    say: l.ch,
    sayRoman: l.tr,
    word: l.word,
    wordTr: l.wordTr,
    emoji: l.emoji,
    en: l.en,
    label: switch (l.group) {
      Group.swara => 'ಸ್ವರ · vowel',
      Group.yogavaha => 'ಯೋಗವಾಹ',
      Group.vyanjana => 'ವ್ಯಂಜನ · consonant',
    },
    color: switch (l.group) {
      Group.swara => CardColor.red,
      Group.yogavaha => CardColor.plum,
      Group.vyanjana => CardColor.blue,
    },
  );

  /// A kagunita form, like ಕಾ (ಕ + ಾ).
  factory CardItem.kagunita(Letter base, VowelSign s) => CardItem(
    ch: base.ch + s.sign,
    say: base.ch + s.sign,
    sayRoman: rootOf(base) + s.tr,
    word: base.word,
    wordTr: base.wordTr,
    label: 'ಕಾಗುಣಿತ · ${base.ch} + ${s.vowel}',
    color: CardColor.blue,
  );

  factory CardItem.number(KNumber n) => CardItem(
    ch: n.ch,
    say: n.word,
    sayRoman: n.wordTr,
    word: n.word,
    wordTr: n.wordTr,
    count: n.n,
    label: 'Number ${n.n}',
    color: CardColor.green,
  );
}

enum CardColor { red, blue, plum, green }

const letters = <Letter>[
  // ಸ್ವರಗಳು — vowels
  Letter('ಅ', 'a', Group.swara, '', 'ಅನಾನಸ್', 'anaanas', '🍍', 'Pineapple'),
  Letter('ಆ', 'aa', Group.swara, '', 'ಆನೆ', 'aane', '🐘', 'Elephant'),
  Letter('ಇ', 'i', Group.swara, '', 'ಇಲಿ', 'ili', '🐭', 'Mouse'),
  Letter('ಈ', 'ii', Group.swara, '', 'ಈರುಳ್ಳಿ', 'iiruLLi', '🧅', 'Onion'),
  Letter('ಉ', 'u', Group.swara, '', 'ಉಂಗುರ', 'ungura', '💍', 'Ring'),
  Letter('ಊ', 'uu', Group.swara, '', 'ಊಟ', 'uuTa', '🍛', 'Meal'),
  Letter('ಋ', 'ru', Group.swara, '', 'ಋಷಿ', 'rushi', '🧘', 'Sage'),
  Letter('ಎ', 'e', Group.swara, '', 'ಎಲೆ', 'ele', '🍃', 'Leaf'),
  Letter('ಏ', 'ee', Group.swara, '', 'ಏಣಿ', 'eeNi', '🪜', 'Ladder'),
  Letter('ಐ', 'ai', Group.swara, '', 'ಐದು', 'aidu', '🖐️', 'Five'),
  Letter('ಒ', 'o', Group.swara, '', 'ಒಂಟೆ', 'onTe', '🐫', 'Camel'),
  Letter('ಓ', 'oo', Group.swara, '', 'ಓದು', 'oodu', '📖', 'Read'),
  Letter('ಔ', 'au', Group.swara, '', 'ಔಷಧಿ', 'aushadhi', '💊', 'Medicine'),
  // ಯೋಗವಾಹಗಳು
  Letter('ಅಂ', 'am', Group.yogavaha, '', 'ಅಂಗಡಿ', 'angaDi', '🏪', 'Shop'),
  Letter(
    'ಅಃ',
    'ah',
    Group.yogavaha,
    '',
    'ದುಃಖ',
    'duhkha',
    '😢',
    'Sadness',
    start: false,
  ),
  // ವರ್ಗೀಯ ವ್ಯಂಜನಗಳು
  Letter('ಕ', 'ka', Group.vyanjana, 'ka', 'ಕಮಲ', 'kamala', '🪷', 'Lotus'),
  Letter('ಖ', 'kha', Group.vyanjana, 'ka', 'ಖಡ್ಗ', 'khaDga', '🗡️', 'Sword'),
  Letter('ಗ', 'ga', Group.vyanjana, 'ka', 'ಗಡಿಯಾರ', 'gaDiyaara', '⏰', 'Clock'),
  Letter('ಘ', 'gha', Group.vyanjana, 'ka', 'ಘಂಟೆ', 'ghanTe', '🔔', 'Bell'),
  Letter(
    'ಙ',
    'nga',
    Group.vyanjana,
    'ka',
    'ವಾಙ್ಮಯ',
    'vaangmaya',
    '📜',
    'Literature',
    start: false,
  ),
  Letter('ಚ', 'cha', Group.vyanjana, 'cha', 'ಚಮಚ', 'chamacha', '🥄', 'Spoon'),
  Letter(
    'ಛ',
    'chha',
    Group.vyanjana,
    'cha',
    'ಛತ್ರಿ',
    'chhatri',
    '☂️',
    'Umbrella',
  ),
  Letter('ಜ', 'ja', Group.vyanjana, 'cha', 'ಜಿಂಕೆ', 'jinke', '🦌', 'Deer'),
  Letter('ಝ', 'jha', Group.vyanjana, 'cha', 'ಝರಿ', 'jhari', '🏞️', 'Stream'),
  Letter(
    'ಞ',
    'nya',
    Group.vyanjana,
    'cha',
    'ಜ್ಞಾನ',
    'jnaana',
    '🧠',
    'Knowledge',
    start: false,
  ),
  Letter('ಟ', 'Ta', Group.vyanjana, 'Ta', 'ಟಗರು', 'Tagaru', '🐏', 'Ram'),
  Letter(
    'ಠ',
    'Tha',
    Group.vyanjana,
    'Ta',
    'ಮಠ',
    'maTha',
    '🛕',
    'Monastery',
    start: false,
  ),
  Letter('ಡ', 'Da', Group.vyanjana, 'Ta', 'ಡಮರು', 'Damaru', '🥁', 'Hand drum'),
  Letter('ಢ', 'Dha', Group.vyanjana, 'Ta', 'ಢಕ್ಕೆ', 'Dhakke', '🪘', 'Big drum'),
  Letter(
    'ಣ',
    'Na',
    Group.vyanjana,
    'Ta',
    'ಬಾಣ',
    'baaNa',
    '🏹',
    'Arrow',
    start: false,
  ),
  Letter(
    'ತ',
    'ta',
    Group.vyanjana,
    'ta',
    'ತರಕಾರಿ',
    'tarakaari',
    '🥕',
    'Vegetables',
  ),
  Letter(
    'ಥ',
    'tha',
    Group.vyanjana,
    'ta',
    'ಕಥೆ',
    'kathe',
    '📚',
    'Story',
    start: false,
  ),
  Letter('ದ', 'da', Group.vyanjana, 'ta', 'ದನ', 'dana', '🐄', 'Cow'),
  Letter('ಧ', 'dha', Group.vyanjana, 'ta', 'ಧ್ವಜ', 'dhvaja', '🚩', 'Flag'),
  Letter('ನ', 'na', Group.vyanjana, 'ta', 'ನವಿಲು', 'navilu', '🦚', 'Peacock'),
  Letter('ಪ', 'pa', Group.vyanjana, 'pa', 'ಪುಸ್ತಕ', 'pustaka', '📕', 'Book'),
  Letter('ಫ', 'pha', Group.vyanjana, 'pa', 'ಫಲ', 'phala', '🍎', 'Fruit'),
  Letter(
    'ಬ',
    'ba',
    Group.vyanjana,
    'pa',
    'ಬಾತುಕೋಳಿ',
    'baatukoLi',
    '🦆',
    'Duck',
  ),
  Letter('ಭ', 'bha', Group.vyanjana, 'pa', 'ಭೂಮಿ', 'bhuumi', '🌍', 'Earth'),
  Letter('ಮ', 'ma', Group.vyanjana, 'pa', 'ಮರ', 'mara', '🌳', 'Tree'),
  // ಅವರ್ಗೀಯ ವ್ಯಂಜನಗಳು
  Letter(
    'ಯ',
    'ya',
    Group.vyanjana,
    'avargiya',
    'ಯಂತ್ರ',
    'yantra',
    '⚙️',
    'Machine',
  ),
  Letter('ರ', 'ra', Group.vyanjana, 'avargiya', 'ರೈಲು', 'railu', '🚂', 'Train'),
  Letter('ಲ', 'la', Group.vyanjana, 'avargiya', 'ಲಾರಿ', 'laari', '🚚', 'Lorry'),
  Letter(
    'ವ',
    'va',
    Group.vyanjana,
    'avargiya',
    'ವಜ್ರ',
    'vajra',
    '💎',
    'Diamond',
  ),
  Letter(
    'ಶ',
    'sha',
    Group.vyanjana,
    'avargiya',
    'ಶಂಖ',
    'shankha',
    '🐚',
    'Conch',
  ),
  Letter(
    'ಷ',
    'Sha',
    Group.vyanjana,
    'avargiya',
    'ಕೃಷಿ',
    'krushi',
    '🌾',
    'Farming',
    start: false,
  ),
  Letter('ಸ', 'sa', Group.vyanjana, 'avargiya', 'ಸೂರ್ಯ', 'suurya', '☀️', 'Sun'),
  Letter(
    'ಹ',
    'ha',
    Group.vyanjana,
    'avargiya',
    'ಹೂವು',
    'huuvu',
    '🌸',
    'Flower',
  ),
  Letter(
    'ಳ',
    'La',
    Group.vyanjana,
    'avargiya',
    'ಬಾಳೆಹಣ್ಣು',
    'baaLehaNNu',
    '🍌',
    'Banana',
    start: false,
  ),
];

const vargas = <Varga>[
  Varga('ka', 'ಕ ವರ್ಗ', 'Ka group'),
  Varga('cha', 'ಚ ವರ್ಗ', 'Cha group'),
  Varga('Ta', 'ಟ ವರ್ಗ', 'Ta group'),
  Varga('ta', 'ತ ವರ್ಗ', 'ta group'),
  Varga('pa', 'ಪ ವರ್ಗ', 'Pa group'),
  Varga('avargiya', 'ಅವರ್ಗೀಯ', 'Other consonants'),
];

const numbers = <KNumber>[
  KNumber('೦', 0, 'ಸೊನ್ನೆ', 'sonne'),
  KNumber('೧', 1, 'ಒಂದು', 'ondu'),
  KNumber('೨', 2, 'ಎರಡು', 'eraDu'),
  KNumber('೩', 3, 'ಮೂರು', 'mooru'),
  KNumber('೪', 4, 'ನಾಲ್ಕು', 'naalku'),
  KNumber('೫', 5, 'ಐದು', 'aidu'),
  KNumber('೬', 6, 'ಆರು', 'aaru'),
  KNumber('೭', 7, 'ಏಳು', 'eeLu'),
  KNumber('೮', 8, 'ಎಂಟು', 'enTu'),
  KNumber('೯', 9, 'ಒಂಬತ್ತು', 'ombattu'),
  KNumber('೧೦', 10, 'ಹತ್ತು', 'hattu'),
];

const signs = <VowelSign>[
  VowelSign('', 'ಅ', 'a'),
  VowelSign('ಾ', 'ಆ', 'aa'),
  VowelSign('ಿ', 'ಇ', 'i'),
  VowelSign('ೀ', 'ಈ', 'ii'),
  VowelSign('ು', 'ಉ', 'u'),
  VowelSign('ೂ', 'ಊ', 'uu'),
  VowelSign('ೃ', 'ಋ', 'ru'),
  VowelSign('ೆ', 'ಎ', 'e'),
  VowelSign('ೇ', 'ಏ', 'ee'),
  VowelSign('ೈ', 'ಐ', 'ai'),
  VowelSign('ೊ', 'ಒ', 'o'),
  VowelSign('ೋ', 'ಓ', 'oo'),
  VowelSign('ೌ', 'ಔ', 'au'),
  VowelSign('ಂ', 'ಅಂ', 'am'),
  VowelSign('ಃ', 'ಅಃ', 'ah'),
];

const praise = [
  'ಶಭಾಷ್!',
  'ಅದ್ಭುತ!',
  'ತುಂಬಾ ಚೆನ್ನಾಗಿದೆ!',
  'ಸೂಪರ್!',
  'ಸರಿ ಉತ್ತರ!',
];

/// One sticker unlocks every 10 stars.
const stickers = [
  '🐘', '🦚', '🪁', '🥭', '🐯', '🌺', '🚂', '🦜', '🏏', '🌈', //
  '🐢', '🦋', '🍦', '🚀', '👑', '🎺', '🐬', '🌻', '🦁', '🏆',
];

/// A picture word: Kannada word, romanised, emoji (shown as a 3D picture)
/// and English meaning.
class Word {
  const Word(this.word, this.wordTr, this.emoji, this.en);
  final String word;
  final String wordTr;
  final String emoji;
  final String en;
}

/// More picture words, all starting with their letter, for variety in the
/// letter cards and games.
const extraWords = <String, List<Word>>{
  'ಅ': [
    Word('ಅಮ್ಮ', 'amma', '👩', 'Mother'),
    Word('ಅಕ್ಕಿ', 'akki', '🍚', 'Rice'),
  ],
  'ಆ': [
    Word('ಆಮೆ', 'aame', '🐢', 'Turtle'),
    Word('ಆಕಾಶ', 'aakaasha', '🌤️', 'Sky'),
  ],
  'ಇ': [Word('ಇರುವೆ', 'iruve', '🐜', 'Ant')],
  'ಈ': [Word('ಈಜು', 'iiju', '🏊', 'Swimming')],
  'ಉ': [
    Word('ಉಪ್ಪು', 'uppu', '🧂', 'Salt'),
    Word('ಉಡುಗೊರೆ', 'uDugore', '🎁', 'Gift'),
  ],
  'ಊ': [Word('ಊರು', 'uuru', '🏘️', 'Village')],
  'ಎ': [Word('ಎತ್ತು', 'ettu', '🐂', 'Ox')],
  'ಏ': [Word('ಏಡಿ', 'eeDi', '🦀', 'Crab')],
  'ಐ': [Word('ಐಸ್‌ಕ್ರೀಮ್', 'aiskriim', '🍨', 'Ice cream')],
  'ಓ': [Word('ಓಟ', 'ooTa', '🏃', 'Running')],
  'ಕ': [
    Word('ಕಪ್ಪೆ', 'kappe', '🐸', 'Frog'),
    Word('ಕರಡಿ', 'karaDi', '🐻', 'Bear'),
  ],
  'ಖ': [Word('ಖಾರ', 'khaara', '🌶️', 'Spicy')],
  'ಗ': [
    Word('ಗಿಳಿ', 'giLi', '🦜', 'Parrot'),
    Word('ಗುಲಾಬಿ', 'gulaabi', '🌹', 'Rose'),
  ],
  'ಘ': [Word('ಘೇಂಡಾಮೃಗ', 'gheenDaamruga', '🦏', 'Rhino')],
  'ಚ': [
    Word('ಚಂದ್ರ', 'chandra', '🌙', 'Moon'),
    Word('ಚಿಟ್ಟೆ', 'chiTTe', '🦋', 'Butterfly'),
  ],
  'ಜ': [
    Word('ಜಿರಾಫೆ', 'jiraaphe', '🦒', 'Giraffe'),
    Word('ಜೇನು', 'jeenu', '🍯', 'Honey'),
  ],
  'ಟ': [Word('ಟೊಮೆಟೊ', 'TomeTo', '🍅', 'Tomato')],
  'ಡ': [Word('ಡಬ್ಬ', 'Dabba', '📦', 'Box')],
  'ತ': [Word('ತೆಂಗಿನಕಾಯಿ', 'tenginakaayi', '🥥', 'Coconut')],
  'ದ': [
    Word('ದೋಣಿ', 'dooNi', '⛵', 'Boat'),
    Word('ದ್ರಾಕ್ಷಿ', 'draakshi', '🍇', 'Grapes'),
  ],
  'ನ': [
    Word('ನಾಯಿ', 'naayi', '🐕', 'Dog'),
    Word('ನಕ್ಷತ್ರ', 'nakshatra', '⭐', 'Star'),
  ],
  'ಪ': [
    Word('ಪಕ್ಷಿ', 'pakshi', '🐦', 'Bird'),
    Word('ಪೆನ್ಸಿಲ್', 'pensil', '✏️', 'Pencil'),
  ],
  'ಬ': [Word('ಬೆಕ್ಕು', 'bekku', '🐈', 'Cat'), Word('ಬಸ್', 'bas', '🚌', 'Bus')],
  'ಮ': [
    Word('ಮೀನು', 'miinu', '🐟', 'Fish'),
    Word('ಮನೆ', 'mane', '🏠', 'House'),
  ],
  'ರ': [Word('ರಾಜ', 'raaja', '🤴', 'King')],
  'ಲ': [Word('ಲಿಂಬೆ', 'limbe', '🍋', 'Lemon')],
  'ವ': [Word('ವಿಮಾನ', 'vimaana', '✈️', 'Aeroplane')],
  'ಶ': [Word('ಶಾಲೆ', 'shaale', '🏫', 'School')],
  'ಸ': [
    Word('ಸಿಂಹ', 'simha', '🦁', 'Lion'),
    Word('ಸೇಬು', 'seebu', '🍏', 'Apple'),
  ],
  'ಹ': [
    Word('ಹಾವು', 'haavu', '🐍', 'Snake'),
    Word('ಹಲ್ಲು', 'hallu', '🦷', 'Tooth'),
  ],
};

/// The letter's main word first, then its extra words.
List<Word> wordsFor(Letter l) => [
  Word(l.word, l.wordTr, l.emoji, l.en),
  ...?extraWords[l.ch],
];

/// Every (letter, word) pair whose word starts with the letter, for the
/// picture and memory games.
List<(Letter, Word)> startWordPairs() => [
  for (final l in letters)
    for (final w in wordsFor(l))
      if (w.word.startsWith(l.ch) && (l.start || w.word != l.word)) (l, w),
];

List<Letter> byGroup(Group g) => letters.where((l) => l.group == g).toList();

/// Consonant root without the inherent "a" (ka → k).
String rootOf(Letter l) => l.tr.substring(0, l.tr.length - 1);

/// The consonant and vowel sign of a kagunita form like ಕಾ, or null.
(Letter, VowelSign)? kagunitaParts(String text) {
  if (text.length != 2) return null;
  for (final l in byGroup(Group.vyanjana)) {
    if (l.ch != text[0]) continue;
    for (final s in signs.skip(1)) {
      if (s.sign == text[1]) return (l, s);
    }
  }
  return null;
}

/// A consonant and its 14 kagunita forms, for tracing.
List<CardItem> kagunitaCards(Letter base) => [
  CardItem.letter(base),
  for (final s in signs.skip(1)) CardItem.kagunita(base, s),
];

/// How [text] (a letter or kagunita form) is spoken: Kannada and roman.
(String, String)? sayingOf(String text) {
  for (final l in letters) {
    if (l.ch == text) return (l.ch, l.tr);
  }
  final k = kagunitaParts(text);
  return k == null ? null : (text, rootOf(k.$1) + k.$2.tr);
}

/// Praise the result screen says aloud.
const spokenPraise = [('ಶಭಾಷ್', 'shabash'), ('ಚೆನ್ನಾಗಿದೆ', 'chennagide')];

/// Everything the app says aloud, as (Kannada, romanized) pairs. Each has a
/// recording in assets/audio/ named by [audioKey]; see tool/generate_audio.dart.
List<(String, String)> spokenTexts() {
  final out = <String, String>{};
  for (final l in letters) {
    out[l.ch] = l.tr;
    out[l.word] = l.wordTr;
    for (final w in extraWords[l.ch] ?? const <Word>[]) {
      out[w.word] = w.wordTr;
    }
  }
  for (final n in numbers) {
    out[n.word] = n.wordTr;
  }
  for (final l in byGroup(Group.vyanjana)) {
    for (final s in signs) {
      out.putIfAbsent(l.ch + s.sign, () => rootOf(l) + s.tr);
    }
  }
  for (final (kn, tr) in spokenPraise) {
    out[kn] = tr;
  }
  return [for (final e in out.entries) (e.key, e.value)];
}

/// ASCII file name for a Kannada text: its code points in hex (ಕಾ → c95_cbe).
String audioKey(String text) =>
    text.runes.map((c) => c.toRadixString(16)).join('_');
