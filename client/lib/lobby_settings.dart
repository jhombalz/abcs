import 'package:flutter/material.dart';

class LobbySettings extends StatelessWidget {
  const LobbySettings({
    super.key,
    required this.room,
    required this.isHost,
    required this.busy,
    required this.onAction,
  });
  final Map<String, dynamic> room;
  final bool isHost;
  final bool busy;
  final void Function(String, Map<String, dynamic>) onAction;

  @override
  Widget build(BuildContext context) {
    if (room['mode'] == 'kikik') {
      final players = room['players'] as List;
      final ready =
          players.length >= 3 && players.every((p) => p['connected'] == true);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'KIKIK',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xffdaf975),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose one card to pass clockwise each turn. Collect four cards of the same rank and call KIKIK first.',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 12),
          const Text(
            '3–12 players · 4 cards each · 12 seconds per pass',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (room['notice'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('${room['notice']}'),
            ),
          if (!ready)
            Text(
              players.length < 3
                  ? 'Invite ${3 - players.length} more player(s) to start.'
                  : 'Waiting for reserved seats to reconnect (up to 60 seconds).',
            ),
          const SizedBox(height: 16),
          if (isHost)
            FilledButton.icon(
              onPressed: !busy && ready
                  ? () => onAction('start_game', {})
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start KIKIK'),
            )
          else
            const Text('Waiting for the host to start KIKIK.'),
        ],
      );
    }
    final category = room['settings']?['category'] as String? ?? 'Mixed';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'SET UP YOUR MATCH',
          style: TextStyle(fontSize: 12, letterSpacing: 2),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(category),
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Mixed',
              child: Text('Mixed: English + math'),
            ),
            DropdownMenuItem(value: 'English', child: Text('English')),
            DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
          ],
          onChanged: isHost && !busy
              ? (value) {
                  if (value != null) {
                    onAction('configure_game', {'category': value});
                  }
                }
              : null,
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: Icon(Icons.quiz_outlined, size: 18),
              label: Text('10 questions'),
            ),
            Chip(
              avatar: Icon(Icons.timer_outlined, size: 18),
              label: Text('15s buzz / 15s answer'),
            ),
            Chip(
              avatar: Icon(Icons.add_circle_outline, size: 18),
              label: Text('+100 correct / 0 incorrect'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Play solo or invite up to 9 friends. Everyone in this room joins the next match. Answers stay hidden.',
        ),
        const SizedBox(height: 20),
        if (isHost)
          FilledButton.icon(
            onPressed: busy ? null : () => onAction('start_game', {}),
            icon: const Icon(Icons.play_arrow),
            label: const Padding(
              padding: EdgeInsets.all(10),
              child: Text('Start game'),
            ),
          )
        else
          Semantics(
            liveRegion: true,
            child: const Text(
              'The host chooses the subject and starts the game.',
            ),
          ),
      ],
    );
  }
}
