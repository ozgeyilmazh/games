import 'locale_storage.dart';

/// Basit çeviri tablosu — UI metinleri.
class AppStrings {
  AppStrings._();

  static AppLocale get _l => LocaleStorage.locale;

  static String get appTitle => _pick(const {
        AppLocale.en: 'Cat Tower',
        AppLocale.tr: 'Kedi Kulesi',
        AppLocale.es: 'Torre de Gatos',
        AppLocale.de: 'Katzen-Turm',
        AppLocale.fr: 'Tour de Chats',
      });

  static String get start => _pick(const {
        AppLocale.en: 'START',
        AppLocale.tr: 'BAŞLA',
        AppLocale.es: 'EMPEZAR',
        AppLocale.de: 'START',
        AppLocale.fr: 'COMMENCER',
      });

  static String get best => _pick(const {
        AppLocale.en: 'Best',
        AppLocale.tr: 'En iyi',
        AppLocale.es: 'Mejor',
        AppLocale.de: 'Best',
        AppLocale.fr: 'Record',
      });

  static String get score => _pick(const {
        AppLocale.en: 'Score',
        AppLocale.tr: 'Skor',
        AppLocale.es: 'Puntos',
        AppLocale.de: 'Punkte',
        AppLocale.fr: 'Score',
      });

  static String get tapToDrop => _pick(const {
        AppLocale.en: 'Tap to drop the cat',
        AppLocale.tr: 'Kediyi bırakmak için dokun',
        AppLocale.es: 'Toca para soltar el gato',
        AppLocale.de: 'Tippen zum Fallenlassen',
        AppLocale.fr: 'Touchez pour lâcher le chat',
      });

  static String get stabilizing => _pick(const {
        AppLocale.en: 'Tower stabilizing…',
        AppLocale.tr: 'Kule dengeleniyor…',
        AppLocale.es: 'Torre estabilizando…',
        AppLocale.de: 'Turm stabilisiert…',
        AppLocale.fr: 'Tour en stabilisation…',
      });

  static String get towerCollapsed => _pick(const {
        AppLocale.en: 'Tower collapsed!',
        AppLocale.tr: 'Kule yıkıldı!',
        AppLocale.es: '¡Torre derrumbada!',
        AppLocale.de: 'Turm eingestürzt!',
        AppLocale.fr: 'Tour effondrée !',
      });

  static String get playAgain => _pick(const {
        AppLocale.en: 'Play again',
        AppLocale.tr: 'Tekrar oyna',
        AppLocale.es: 'Jugar de nuevo',
        AppLocale.de: 'Nochmal spielen',
        AppLocale.fr: 'Rejouer',
      });

  static String get watchAdContinue => _pick(const {
        AppLocale.en: 'Watch Ad & Continue',
        AppLocale.tr: 'Reklam izle ve devam et',
        AppLocale.es: 'Ver anuncio y continuar',
        AppLocale.de: 'Werbung ansehen & weiter',
        AppLocale.fr: 'Voir une pub et continuer',
      });

  static String get loadingAd => _pick(const {
        AppLocale.en: 'Loading ad…',
        AppLocale.tr: 'Reklam yükleniyor…',
        AppLocale.es: 'Cargando anuncio…',
        AppLocale.de: 'Werbung lädt…',
        AppLocale.fr: 'Chargement de la pub…',
      });

  static String get quit => _pick(const {
        AppLocale.en: 'Quit',
        AppLocale.tr: 'Çık',
        AppLocale.es: 'Salir',
        AppLocale.de: 'Beenden',
        AppLocale.fr: 'Quitter',
      });

  static String continuesLeft(int n) => _pick({
        AppLocale.en: 'Watch an ad to continue.\n$n left this run.',
        AppLocale.tr: 'Devam etmek için reklam izle.\nBu turda $n hak kaldı.',
        AppLocale.es: 'Mira un anuncio para continuar.\nQuedan $n en esta partida.',
        AppLocale.de: 'Werbung ansehen zum Weiterspielen.\nNoch $n in diesem Lauf.',
        AppLocale.fr: 'Regardez une pub pour continuer.\n$n restant(s) cette partie.',
      });

  static String get noContinues => _pick(const {
        AppLocale.en: 'No continues left.',
        AppLocale.tr: 'Devam hakkı kalmadı.',
        AppLocale.es: 'No quedan continuaciones.',
        AppLocale.de: 'Keine Continues mehr.',
        AppLocale.fr: 'Plus de continues.',
      });

  static String get adLoadFailed => _pick(const {
        AppLocale.en: 'Ad could not load. Check internet and try again.',
        AppLocale.tr: 'Reklam yüklenemedi. İnterneti kontrol edip tekrar dene.',
        AppLocale.es: 'No se pudo cargar el anuncio. Revisa internet e inténtalo.',
        AppLocale.de: 'Werbung konnte nicht geladen werden. Internet prüfen.',
        AppLocale.fr: 'Impossible de charger la pub. Vérifiez internet.',
      });

  static String get pleaseWaitTapAgain => _pick(const {
        AppLocale.en: 'Please wait and tap again.',
        AppLocale.tr: 'Bekleyip tekrar dokun.',
        AppLocale.es: 'Espera y toca de nuevo.',
        AppLocale.de: 'Bitte warten und erneut tippen.',
        AppLocale.fr: 'Attendez et touchez à nouveau.',
      });

  static String get language => _pick(const {
        AppLocale.en: 'Language',
        AppLocale.tr: 'Dil',
        AppLocale.es: 'Idioma',
        AppLocale.de: 'Sprache',
        AppLocale.fr: 'Langue',
      });

  static String labelFor(AppLocale locale) => switch (locale) {
        AppLocale.en => 'English',
        AppLocale.tr => 'Türkçe',
        AppLocale.es => 'Español',
        AppLocale.de => 'Deutsch',
        AppLocale.fr => 'Français',
      };

  static String _pick(Map<AppLocale, String> map) =>
      map[_l] ?? map[AppLocale.en]!;
}
