import 'package:shared_preferences/shared_preferences.dart';

const _key = 'buzzclub.kikik-seat.v1';
Future<String?> readSeat() => SharedPreferencesAsync().getString(_key);
Future<void> writeSeat(String value) =>
    SharedPreferencesAsync().setString(_key, value);
Future<void> removeSeat() => SharedPreferencesAsync().remove(_key);
