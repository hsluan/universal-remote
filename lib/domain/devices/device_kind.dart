/// What a device is, independent of how the app reaches it.
///
/// Persisted by [name]: rename a value only together with a storage migration.
enum DeviceKind {
  airConditioner,
  fan,
  light,
  plug,
  tv,
  camera,
  vehicle;

  static DeviceKind? fromName(Object? name) => values.asNameMap()[name];
}
