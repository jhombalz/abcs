import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'game_panel.dart';
import 'game_sounds.dart';
import 'lobby_settings.dart';

void main() => runApp(const BuzzClubApp());

class BuzzClubApp extends StatelessWidget {
  const BuzzClubApp({super.key, this.connectToServer = true});
  final bool connectToServer;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Buzz Club',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffdaf975),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff101a19),
      useMaterial3: true,
    ),
    home: LobbyPage(connectToServer: connectToServer),
  );
}

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key, this.connectToServer = true});
  final bool connectToServer;
  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  late final io.Socket socket;
  final name = TextEditingController();
  final code = TextEditingController();
  Map<String, dynamic>? room;
  bool connected = false, busy = false;
  bool nameConfirmed = false;
  bool soundEnabled = false;
  final sounds = GameSounds();
  String? lastAudioKey;
  String? error;
  Timer? timeout;
  @override
  void initState() {
    super.initState();
    const configured = String.fromEnvironment('SERVER_URL');
    final url = configured.isNotEmpty
        ? configured
        : kReleaseMode
        ? 'https://api.iconcept-faas.lguapp.com'
        : 'http://${Uri.base.host.isEmpty ? 'localhost' : Uri.base.host}:8099';
    socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    socket.onConnect((_) {
      if (mounted) {
        setState(() {
          connected = true;
          error = null;
        });
      }
    });
    socket.onConnectError((_) {
      if (mounted) {
        setState(
          () => error =
              'Cannot connect to the game server at $url. Check that it is running.',
        );
      }
    });
    socket.onDisconnect((_) {
      timeout?.cancel();
      if (mounted) {
        setState(() {
          connected = false;
          busy = false;
          room = null;
          error = 'Disconnected. Rejoin after reconnecting.';
        });
      }
    });
    socket.on('room_updated', (data) {
      if (mounted) receiveRoom(data);
    });
    socket.on('room_expired', (_) {
      if (mounted) {
        setState(() {
          room = null;
          error = 'Room expired. Create a new room.';
        });
      }
    });
    if (widget.connectToServer) socket.connect();
  }

  void receiveRoom(dynamic data) {
    final next = Map<String, dynamic>.from(data as Map);
    final status = next['status'];
    final feedback = next['feedback'] as Map?;
    final audioKey =
        '${next['question']?['id']}|$status|${feedback?['kind']}|${feedback?['playerId']}';
    if (soundEnabled && audioKey != lastAudioKey) {
      final cue = status == 'GAME_FINISHED'
          ? 'finish'
          : feedback?['kind'] == 'correct'
          ? 'point'
          : status == 'ANSWERING'
          ? 'buzz'
          : status == 'QUESTION_ACTIVE' && feedback == null
          ? 'round'
          : null;
      if (cue != null) unawaited(sounds.play(cue));
    }
    lastAudioKey = audioKey;
    setState(() => room = next);
  }

  void toggleSound() {
    setState(() => soundEnabled = !soundEnabled);
    if (soundEnabled) {
      unawaited(sounds.play('round'));
    } else {
      unawaited(sounds.mute());
    }
  }

  void action(String event, [Map<String, dynamic>? payload]) {
    if (!connected || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    var completed = false;
    timeout = Timer(const Duration(seconds: 6), () {
      completed = true;
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Server did not respond. Try again.';
        });
      }
    });
    void ack(dynamic data) {
      if (!mounted || completed) return;
      completed = true;
      timeout?.cancel();
      setState(() => busy = false);
      if (data is! Map || data['ok'] != true) {
        setState(
          () =>
              error = data is Map ? '${data['error']}' : 'Unexpected response.',
        );
        return;
      }
      if (event == 'leave_room') {
        setState(() => room = null);
      } else {
        receiveRoom(data['room']);
      }
    }

    socket.emitWithAck(
      event,
      event == 'leave_room'
          ? null
          : payload ?? {'name': name.text.trim(), 'code': code.text},
      ack: ack,
    );
  }

  void confirmName() {
    if (name.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      name.text = name.text.trim();
      nameConfirmed = true;
    });
  }

  @override
  void dispose() {
    timeout?.cancel();
    socket.dispose();
    sounds.dispose();
    name.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeRoom = room;
    final players = (activeRoom?['players'] as List?) ?? [];
    final playing = activeRoom != null && activeRoom['status'] != 'WAITING';
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GOOD COMPANY. GREAT COMPETITION.',
          style: TextStyle(letterSpacing: 2, fontSize: 11),
        ),
        const SizedBox(height: 24),
        const Text(
          'Quick minds.\nFast fingers.',
          style: TextStyle(
            fontSize: 48,
            height: 1.1,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          'Your moment.',
          style: TextStyle(
            fontSize: 48,
            height: 1.1,
            fontWeight: FontWeight.bold,
            color: Color(0xffdaf975),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'A little knowledge. A lot of friendly rivalry. Bring your people together and get ready to buzz.',
          style: TextStyle(fontSize: 17, height: 1.7, color: Color(0xffa7b7ad)),
        ),
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 160,
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xffdaf975),
              borderRadius: BorderRadius.all(Radius.elliptical(100, 70)),
              boxShadow: [
                BoxShadow(color: Color(0xff718339), offset: Offset(0, 14)),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'BUZZ',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontSize: 28,
                color: Color(0xff15231c),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        const Text('1-10 players | Solo or with friends'),
      ],
    );
    final panel = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xff1a2723),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff35443b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'BUZZ CLUB | QUIZ ROOM',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: Color(0xffdaf975),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            activeRoom != null
                ? playing
                      ? 'Let your knowledge shine.'
                      : 'The room is yours.'
                : nameConfirmed
                ? 'Make room for fun.'
                : 'What should we call you?',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            activeRoom == null
                ? nameConfirmed
                      ? 'Start a fresh room or join your friends.'
                      : 'Enter your display name to get started.'
                : playing
                ? '15 seconds to buzz. 15 seconds to answer.'
                : 'Share your code and gather your players.',
          ),
          const SizedBox(height: 24),
          if (error != null) ...[
            Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 16),
          ],
          if (activeRoom == null && !nameConfirmed) ...[
            TextField(
              controller: name,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: 'Your display name',
                helperText: 'This is how other players will see you.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => confirmName(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: name.text.trim().isNotEmpty ? confirmName : null,
              child: const Text('OK'),
            ),
          ] else if (activeRoom == null) ...[
            Text(
              'Playing as ${name.text}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => nameConfirmed = false),
                child: const Text('Change name'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: connected && !busy && name.text.trim().isNotEmpty
                  ? () => action('create_room')
                  : null,
              child: const Text('Create a room'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('or join the crew')),
            ),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Six-digit room code',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed:
                  connected &&
                      !busy &&
                      name.text.trim().isNotEmpty &&
                      code.text.length == 6
                  ? () => action('join_room')
                  : null,
              child: const Text('Join room'),
            ),
            const SizedBox(height: 8),
            Text(
              busy
                  ? 'Please wait for the current request.'
                  : !connected
                  ? 'Waiting for the game server to connect.'
                  : code.text.length != 6
                  ? 'Enter the six-digit code from the host\'s room.'
                  : 'Ready to join the host\'s room.',
              style: const TextStyle(fontSize: 12),
            ),
          ] else ...[
            if (!playing)
              Center(
                child: SelectableText(
                  '${activeRoom['code']}',
                  style: const TextStyle(
                    fontSize: 40,
                    letterSpacing: 5,
                    color: Color(0xffdaf975),
                  ),
                ),
              ),
            if (!playing)
              TextButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(text: '${activeRoom['code']}'),
                    );
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => error =
                            'Copy unavailable. Select the code to copy it.',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy room code'),
              ),
            if (playing)
              Text(
                'Room ${activeRoom['code']} · ${players.length} player${players.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Color(0xffa7b7ad)),
              ),
            if (!playing) const SizedBox(height: 16),
            if (!playing) Text('In the room · ${players.length} / 10'),
            if (!playing)
              for (final player in players)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(
                      (player['name'] as String).characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(
                    '${player['name']}${player['id'] == socket.id ? ' (you)' : ''}',
                  ),
                  trailing: Text(
                    player['id'] == activeRoom['hostId'] ? 'HOST' : 'PLAYER',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            const SizedBox(height: 16),
            if (activeRoom['status'] == 'WAITING')
              LobbySettings(
                room: activeRoom,
                isHost: activeRoom['hostId'] == socket.id,
                busy: busy,
                onAction: (event, payload) => action(event, payload),
              )
            else
              GamePanel(
                room: activeRoom,
                playerId: socket.id,
                busy: busy,
                onAction: (event, payload) => action(event, payload),
              ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: busy ? null : () => action('leave_room'),
              child: const Text('Leave room'),
            ),
          ],
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'b. buzz club',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: connected
                            ? const Color(0xffdaf975)
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(connected ? 'Connected' : 'Connecting…'),
                      IconButton(
                        tooltip: soundEnabled
                            ? 'Mute game sounds'
                            : 'Enable game sounds',
                        onPressed: toggleSound,
                        icon: Icon(
                          soundEnabled
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 48),
                  LayoutBuilder(
                    builder: (context, constraints) => playing
                        ? panel
                        : constraints.maxWidth >= 800
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: intro),
                              const SizedBox(width: 64),
                              Expanded(child: panel),
                            ],
                          )
                        : Column(
                            children: [
                              intro,
                              const SizedBox(height: 40),
                              panel,
                            ],
                          ),
                  ),
                  const SizedBox(height: 40),
                  const Divider(),
                  const Text('A friendly battle of brains.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
