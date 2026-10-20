import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../domain/encoders/ac/ac_encoder_registry.dart';
import '../../../../domain/models/ac_brand.dart';
import '../../../../domain/models/ac_device.dart';
import '../../../../domain/models/ac_state.dart';
import '../../../../domain/pairing/ac_code_search.dart';
import '../../../../domain/repositories/ac_brand_repository.dart';
import '../../../../domain/repositories/ac_device_repository.dart';
import '../../../../domain/use_cases/transmit_ac_state_use_case.dart';
import '../../../core/transmit_error.dart';

enum PairingStep { brand, prepare, testing, verify, name, notFound }

class AcPairingViewModel extends ChangeNotifier {
  AcPairingViewModel({
    required this.brandRepository,
    required this.deviceRepository,
    required this.registry,
    required this.transmitAcState,
    this.autoInterval = 4,
  });

  final AcBrandRepository brandRepository;
  final AcDeviceRepository deviceRepository;
  final AcEncoderRegistry registry;
  final TransmitAcStateUseCase transmitAcState;

  /// Seconds auto mode waits for the user's answer before trying the next code.
  final int autoInterval;

  static const List<String> roomSuggestions = ['Living room', 'Bedroom', 'Kitchen', 'Office'];

  PairingStep _step = PairingStep.brand;
  PairingStep get step => _step;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<AcBrand> _brands = const [];
  List<String> _existingNames = const [];
  List<String> _pairedBrandNames = const [];

  String _query = '';
  String get query => _query;

  /// Brands matching the search box, alphabetical.
  List<AcBrand> get filteredBrands {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _brands;
    return _brands.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  /// Suggestions: brands already paired in this app, then the most common brands in Vietnam.
  List<AcBrand> get suggestedBrands {
    final paired = _brands.where((b) => _pairedBrandNames.contains(b.name));
    final popular = _brands.where((b) => b.isPopular && !_pairedBrandNames.contains(b.name)).toList()
      ..sort((a, b) => a.rank!.compareTo(b.rank!));
    return [...paired, ...popular];
  }

  bool isPairedBrand(AcBrand brand) => _pairedBrandNames.contains(brand.name);

  AcBrand? _brand;

  /// The chosen brand; `null` when the user does not know it.
  AcBrand? get brand => _brand;

  AcCodeSearch? _search;
  AcCodeSearch? get search => _search;

  bool _isSending = false;
  bool get isSending => _isSending;

  /// Increments on every transmission; the view pulses its IR indicator on change.
  int _sendCount = 0;
  int get sendCount => _sendCount;

  bool _autoMode = false;
  bool get autoMode => _autoMode;

  int _countdown = 0;
  int get countdown => _countdown;

  /// Whether the user went past a code in auto mode and may want it back.
  bool get canGoBack => _search?.hasPrevious ?? false;

  bool _verifySent = false;
  bool get verifySent => _verifySent;

  String _name = '';
  String get name => _name;

  String? _room;
  String? get room => _room;

  String? _error;
  String? get error => _error;

  Timer? _autoTimer;
  bool _disposed = false;

  /// Brand shown for the found code: the chosen one, or the first catalog brand known to use it.
  String get detectedBrandName {
    final chosen = _brand;
    if (chosen != null) return chosen.name;
    final matchId = _search?.match?.id ?? _search?.current.id;
    for (final b in _brands) {
      if (b.codeIds.contains(matchId)) return b.name;
    }
    return 'Air conditioner';
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _brands = await brandRepository.getBrands();
      final devices = await deviceRepository.getAll();
      _existingNames = [for (final d in devices) d.name];
      _pairedBrandNames = {for (final d in devices) d.brandName}.toList();
    } catch (e) {
      _error = 'Could not load the brand list.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void chooseBrand(AcBrand brand) => _startSearch(brand);

  void chooseUnknownBrand() => _startSearch(null);

  void _startSearch(AcBrand? brand) {
    _brand = brand;
    final preferred = brand?.codeIds ?? const <String>[];
    final candidates = registry.candidatesFor(preferred);
    _search = AcCodeSearch(
      candidates: candidates,
      preferredCount: candidates.where((c) => preferred.contains(c.id)).length,
    );
    _go(PairingStep.prepare);
  }

  void startTesting() {
    _search?.restart();
    _go(PairingStep.testing);
    _sendProbe();
  }

  Future<void> sendAgain() => _sendProbe();

  /// The AC beeped or turned on.
  void answerYes() {
    final search = _search;
    if (search == null || search.isExhausted) return;
    setAutoMode(false);
    search.accept();
    _verifySent = false;
    _go(PairingStep.verify);
  }

  /// No response: try the next code.
  void answerNo() {
    final search = _search;
    if (search == null) return;
    search.reject();
    if (search.isExhausted) {
      setAutoMode(false);
      _go(PairingStep.notFound);
      return;
    }
    _countdown = autoInterval;
    notifyListeners();
    _sendProbe();
  }

  /// Return to the previous code (the AC answered just before auto mode moved on).
  void goBackOne() {
    final search = _search;
    if (search == null || !search.hasPrevious) return;
    setAutoMode(false);
    search.back();
    notifyListeners();
    _sendProbe();
  }

  void setAutoMode(bool enabled) {
    if (enabled == _autoMode) return;
    _autoMode = enabled;
    _autoTimer?.cancel();
    _autoTimer = null;
    if (enabled) {
      _countdown = autoInterval;
      _autoTimer = Timer.periodic(const Duration(seconds: 1), (_) => _autoTick());
    }
    notifyListeners();
  }

  void _autoTick() {
    if (_isSending || _step != PairingStep.testing) return;
    _countdown--;
    if (_countdown <= 0) {
      answerNo();
    } else {
      notifyListeners();
    }
  }

  /// Confirms the match by switching the AC off with the same code.
  Future<void> sendVerifyOff() async {
    final match = _search?.match;
    if (match == null) return;
    final ok = await _transmit(() => transmitAcState.executeWith(match, AcState.probe.copyWith(isPowerOn: false)));
    if (ok) {
      _verifySent = true;
      notifyListeners();
    }
  }

  void verifyYes() {
    _name = _uniqueName('$detectedBrandName AC');
    _go(PairingStep.name);
  }

  /// The AC did not turn off: the match was a false positive, keep searching.
  void verifyNo() {
    final search = _search;
    if (search == null) return;
    search.rejectMatch();
    if (search.isExhausted) {
      _go(PairingStep.notFound);
      return;
    }
    _go(PairingStep.testing);
    _sendProbe();
  }

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setRoom(String? value) {
    _room = (value == null || value.trim().isEmpty) ? null : value.trim();
    notifyListeners();
  }

  bool get canSave => _name.trim().isNotEmpty && _search?.match != null;

  /// Saves the paired AC and returns it, or `null` when nothing was matched.
  Future<AcDevice?> save() async {
    final match = _search?.match;
    if (match == null || !canSave) return null;
    final device = AcDevice(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: _name.trim(),
      brandName: detectedBrandName,
      codeId: match.id,
      room: _room,
      // The verify step switched the AC off.
      state: match.capabilities.normalize(AcState.probe.copyWith(isPowerOn: false)),
    );
    await deviceRepository.save(device);
    return device;
  }

  /// Wizard back button. Returns `false` on the first step, where the route should pop.
  bool back() {
    setAutoMode(false);
    switch (_step) {
      case PairingStep.brand:
        return false;
      case PairingStep.prepare:
      case PairingStep.notFound:
        _go(PairingStep.brand);
      case PairingStep.testing:
        _go(PairingStep.prepare);
      case PairingStep.verify:
        _search?.clearMatch();
        _go(PairingStep.testing);
      case PairingStep.name:
        _go(PairingStep.verify);
    }
    return true;
  }

  void restart() {
    setAutoMode(false);
    _search = null;
    _brand = null;
    _go(PairingStep.brand);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _sendProbe() async {
    final search = _search;
    if (search == null || search.isExhausted) return;
    final encoder = search.current;
    await _transmit(() => transmitAcState.executeWith(encoder, AcState.probe));
  }

  Future<bool> _transmit(Future<Object?> Function() send) async {
    if (_isSending) return false;
    _isSending = true;
    _error = null;
    notifyListeners();
    HapticFeedback.lightImpact().ignore();
    try {
      await send();
      _sendCount++;
      return true;
    } catch (e) {
      setAutoMode(false);
      _error = describeTransmitError(e);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void _go(PairingStep step) {
    _step = step;
    _error = null;
    notifyListeners();
  }

  String _uniqueName(String base) {
    if (!_existingNames.contains(base)) return base;
    var n = 2;
    while (_existingNames.contains('$base $n')) {
      n++;
    }
    return '$base $n';
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoTimer?.cancel();
    super.dispose();
  }
}
