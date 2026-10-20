import 'dart:async';

import '../models/ir_send_record.dart';

/// In-memory log of the latest IR transmissions, newest first.
///
/// The phone cannot hear whether an appliance reacted, so when a code misbehaves
/// on a real AC this log (frames, timings, errors) is what explains it.
class IrSendLog {
  IrSendLog({this.capacity = 50}) : assert(capacity > 0);

  final int capacity;
  final List<IrSendRecord> _records = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Newest first.
  List<IrSendRecord> get records => List.unmodifiable(_records);

  /// Fires after every [add] and [clear].
  Stream<void> get changes => _changes.stream;

  void add(IrSendRecord record) {
    _records.insert(0, record);
    if (_records.length > capacity) _records.removeLast();
    _changes.add(null);
  }

  void clear() {
    _records.clear();
    _changes.add(null);
  }

  /// The whole log as plain text, oldest first.
  String export() => _records.reversed.map((r) => r.toLogLine()).join('\n');
}
