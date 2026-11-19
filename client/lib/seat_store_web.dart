import 'package:web/web.dart' as web;

const _key = 'buzzclub.kikik-seat.v1';
Future<String?> readSeat() async => web.window.sessionStorage.getItem(_key);
Future<void> writeSeat(String value) async =>
    web.window.sessionStorage.setItem(_key, value);
Future<void> removeSeat() async => web.window.sessionStorage.removeItem(_key);
