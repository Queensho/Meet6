class MiniGameSelectionService {
  const MiniGameSelectionService._();

  static String selectedGameKey = 'two_truths_one_lie';

  static void select(String gameKey) {
    selectedGameKey = gameKey;
  }

  static String get selectedTitle {
    switch (selectedGameKey) {
      case 'red_flag_green_flag':
        return 'Red Flag / Green Flag';
      default:
        return 'İki Doğru Bir Yalan';
    }
  }
}
