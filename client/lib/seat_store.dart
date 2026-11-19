import 'dart:convert';

import 'seat_store_native.dart'
    if (dart.library.js_interop) 'seat_store_web.dart'
    as platform;

/// Web uses tab-scoped session storage so different tabs can own different seats.
class SeatStore {
  Map<String, dynamic>? _memory;
  Future<Map<String, dynamic>?> load(String server) async {
    try {
      final value = await platform.readSeat();
      if (value != null) {
        _memory = Map<String, dynamic>.from(jsonDecode(value) as Map);
      }
    } catch (_) {
      /* Storage can be unavailable in private browsing. */
    }
    return _memory?['server'] == server ? _memory : null;
  }

  Future<void> save(Map<String, dynamic> seat) async {
    _memory = seat;
    try {
      await platform.writeSeat(jsonEncode(seat));
    } catch (_) {
      /* In-memory reconnect still works. */
    }
  }

  Future<void> clear() async {
    _memory = null;
    try {
      await platform.removeSeat();
    } catch (_) {
      /* No persistent seat is required. */
    }
  }
}
