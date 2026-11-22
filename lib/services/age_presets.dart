
import 'package:vesta_app/l10n/tr.dart';/// Recommended filters by the minor's age.
/// They are a reasonable starting point, not an exhaustive list: the guardian
/// can review them and remove them later in Filters. They are based on the
/// platforms' own minimum ages (13 for social networks) and on the ban on
/// gambling and adult content for minors.
class AgePreset {
  final String title;
  final String description;
  final List<String> domains;
  final List<String> apps;
  final bool safeSearch;

  const AgePreset({
    required this.title,
    required this.description,
    required this.domains,
    required this.apps,
    required this.safeSearch,
  });

  bool get isEmpty => domains.isEmpty && apps.isEmpty && !safeSearch;
}

class AgePresets {
  AgePresets._();

  static const adult = [
    'pornhub.com', 'xvideos.com', 'xnxx.com', 'xhamster.com', 'redtube.com',
    'youporn.com', 'onlyfans.com', 'chaturbate.com', 'stripchat.com',
    'brazzers.com',
  ];

  static const gambling = [
    'bet365.com', 'betway.com', 'codere.com', 'williamhill.com',
    '888casino.com', 'pokerstars.com', 'stake.com', '1xbet.com',
    'rushbet.co', 'wplay.co', 'betplay.com.co', 'sportium.es',
  ];

  static const strangerChat = [
    'chatroulette.com', 'ome.tv', 'monkey.app', 'yubo.live', 'chatrandom.com',
  ];

  static const socialDomains = [
    'tiktok.com', 'instagram.com', 'snapchat.com', 'facebook.com', 'x.com',
    'twitter.com', 'discord.com', 'reddit.com',
  ];

  static const socialApps = [
    'com.zhiliaoapp.musically', 'com.ss.android.ugc.trill',
    'com.instagram.android', 'com.snapchat.android', 'com.facebook.katana',
    'com.twitter.android', 'com.discord', 'com.reddit.frontpage',
  ];

  static AgePreset forAge(int age) {
    if (age < 13) {
      return AgePreset(
        title: tr('Menores de 13 años'),
        description: tr('Bloquea contenido adulto, apuestas, chats con desconocidos y redes sociales (requieren 13 años), y activa la búsqueda segura.'),
        domains: [...adult, ...gambling, ...strangerChat, ...socialDomains],
        apps: socialApps,
        safeSearch: true,
      );
    }
    if (age < 16) {
      return AgePreset(
        title: tr('13 a 15 años'),
        description: tr('Bloquea contenido adulto, apuestas y chats con desconocidos, y activa la búsqueda segura. Las redes sociales quedan permitidas: puedes ponerles un límite diario.'),
        domains: [...adult, ...gambling, ...strangerChat],
        apps: [],
        safeSearch: true,
      );
    }
    if (age < 18) {
      return AgePreset(
        title: tr('16 y 17 años'),
        description: tr('Bloquea contenido adulto y apuestas y activa la búsqueda segura.'),
        domains: [...adult, ...gambling],
        apps: [],
        safeSearch: true,
      );
    }
    return AgePreset(
      title: tr('Mayor de edad'),
      description: tr('No se recomiendan restricciones automáticas.'),
      domains: [],
      apps: [],
      safeSearch: false,
    );
  }
}
