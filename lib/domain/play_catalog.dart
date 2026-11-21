/// Presentation metadata only. Progression and rewards remain in GameStore/server.
class PlayMode {
  final String kind, title, instruction;
  const PlayMode(this.kind, this.title, this.instruction);
}

const playModes = [
  PlayMode(
    'chrono',
    'Série chrono',
    '60 secondes · reconnais les oiseaux et bats ton record !',
  ),
  PlayMode('hidden', 'Oiseau caché', 'Découvre les lettres du nom avec Pépi.'),
  PlayMode(
    'image_choice',
    'Mission jumelles',
    'Lis la mission, puis trouve la bonne photo.',
  ),
  PlayMode('photo', 'Jeu photo', 'Identifie l’oiseau grâce à sa photo.'),
  PlayMode(
    'quiz',
    'Les secrets des oiseaux',
    'Apprends avec Pépi : nourriture, nids et petits secrets.',
  ),
  PlayMode(
    'song',
    'À qui ce chant ?',
    'Écoute, puis trouve la photo. Chants en préparation.',
  ),
  PlayMode(
    'ultimate',
    'Le défi ultime',
    'Relie nom, photo et chant. Chants en préparation.',
  ),
];

String stageTitle(int level) => const [
  'Premier regard',
  'Aventurier',
  'Explorateur',
  'Ornitho en herbe',
  'Expert',
][(level - 1).clamp(0, 4)];
String stageDescription(int level) => level == 1
    ? 'Photos et petits quiz · 6 défis'
    : 'Photos, indices et quiz · 6 défis';
