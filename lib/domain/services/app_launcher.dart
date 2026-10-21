/// Opens other apps installed on the phone (the makers' own apps).
abstract interface class AppLauncher {
  Future<bool> isInstalled(String packageName);

  /// Starts the app; returns `false` when it is not installed.
  Future<bool> launch(String packageName);

  /// Opens the app's store page, to install it.
  Future<void> openStorePage(String packageName);
}
