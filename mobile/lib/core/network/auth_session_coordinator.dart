typedef SessionExpirationListener = void Function();

class AuthSessionCoordinator {
  final Set<SessionExpirationListener> _listeners =
      <SessionExpirationListener>{};
  int _revision = 0;
  bool _refreshAllowed = true;

  int captureRevision() => _revision;

  bool isCurrent(int revision) => revision == _revision;

  bool get refreshAllowed => _refreshAllowed;

  void activateSession() {
    _revision += 1;
    _refreshAllowed = true;
  }

  void deactivateSession() {
    _revision += 1;
    _refreshAllowed = false;
  }

  void expireSession() {
    deactivateSession();
    for (final SessionExpirationListener listener in List.of(_listeners)) {
      listener();
    }
  }

  void addExpirationListener(SessionExpirationListener listener) {
    _listeners.add(listener);
  }

  void removeExpirationListener(SessionExpirationListener listener) {
    _listeners.remove(listener);
  }
}
