/// Logical TV remote buttons, keyed as in the bundled JSON database.
enum TvButton {
  power('power', 'Power'),
  volUp('vol_up', 'Vol +'),
  volDown('vol_down', 'Vol -'),
  chUp('ch_up', 'Ch +'),
  chDown('ch_down', 'Ch -'),
  mute('mute', 'Mute'),
  up('up', 'Up'),
  down('down', 'Down'),
  left('left', 'Left'),
  right('right', 'Right'),
  ok('ok', 'OK'),
  back('back', 'Back'),
  home('home', 'Home'),
  menu('menu', 'Menu'),
  source('source', 'Source'),
  digit0('digit_0', '0'),
  digit1('digit_1', '1'),
  digit2('digit_2', '2'),
  digit3('digit_3', '3'),
  digit4('digit_4', '4'),
  digit5('digit_5', '5'),
  digit6('digit_6', '6'),
  digit7('digit_7', '7'),
  digit8('digit_8', '8'),
  digit9('digit_9', '9');

  const TvButton(this.key, this.label);

  final String key;
  final String label;

  /// Buttons every TV code set must define.
  static const Set<TvButton> essentials = {power, volUp, volDown, chUp, chDown, mute};

  static const List<TvButton> digits = [
    digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9,
  ];

  static TvButton? fromKey(String key) {
    for (final button in values) {
      if (button.key == key) return button;
    }
    return null;
  }
}
