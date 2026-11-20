import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kikik_panel.dart' show PlayingCard;
import 'kikik_table.dart';

const butbutayRanks = [
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K',
];

class ButbutayPanel extends StatefulWidget {
  const ButbutayPanel({
    super.key,
    required this.room,
    required this.playerId,
    required this.busy,
    required this.onAction,
  });
  final Map<String, dynamic> room;
  final String? playerId;
  final bool busy;
  final void Function(String, Map<String, dynamic>) onAction;
  @override
  State<ButbutayPanel> createState() => _ButbutayPanelState();
}

class _ButbutayPanelState extends State<ButbutayPanel> {
  final selected = <String>{};
  final focus = FocusNode(debugLabel: 'Butbutay controls');
  String rank = 'K';
  String? turnId;
  @override
  void initState() {
    super.initState();
    turnId = widget.room['turnId'] as String?;
  }

  @override
  void didUpdateWidget(covariant ButbutayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.room['turnId'] as String?;
    if (next != turnId || widget.room['status'] != 'DROPPING') selected.clear();
    turnId = next;
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  bool get canDrop =>
      !widget.busy &&
      widget.room['status'] == 'DROPPING' &&
      widget.room['currentPlayerId'] == widget.playerId;
  bool get canLie =>
      !widget.busy &&
      widget.room['status'] == 'CHALLENGE' &&
      widget.room['currentDrop']?['playerId'] != widget.playerId;
  void toggle(String id) {
    if (!canDrop) return;
    setState(() {
      if (!selected.remove(id) && selected.length < 4) selected.add(id);
    });
  }

  void drop() {
    if (!canDrop || selected.isEmpty) return;
    widget.onAction('drop_cards', {
      'turnId': widget.room['turnId'],
      'cardIds': selected.toList(),
      'quantity': selected.length,
      'rank': rank,
    });
  }

  void lie() {
    if (canLie) {
      widget.onAction('call_lie', {'dropId': widget.room['currentDrop']['id']});
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final players = List<Map>.from(room['players'] as List);
    String name(dynamic id) =>
        '${players.where((p) => p['id'] == id).firstOrNull?['name'] ?? 'Player'}';
    final status = room['status'];
    final finished = status == 'GAME_FINISHED';
    final paused = status == 'PAUSED';
    final pending = room['currentDrop'] as Map?;
    final result = room['result'] as Map?;
    final winner = room['winner'] as Map?;
    final mine = room['currentPlayerId'] == widget.playerId;
    final seconds = (room['secondsLeft'] as num? ?? 0).toInt();
    final hand = List<Map>.from(room['hand'] as List? ?? [])
      ..sort((a, b) {
        final comparison = butbutayRanks
            .indexOf(a['rank'] as String)
            .compareTo(butbutayRanks.indexOf(b['rank'] as String));
        return comparison != 0
            ? comparison
            : (a['suit'] as String).compareTo(b['suit'] as String);
      });
    final duration = status == 'CHALLENGE'
        ? 7
        : status == 'CHALLENGE_RESULT'
        ? 4
        : 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          autofocus: true,
          focusNode: focus,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.keyL &&
                canLie) {
              lie();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 8,
                spacing: 12,
                children: [
                  const Text(
                    'BUTBUTAY',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xffdaf975),
                    ),
                  ),
                  Text(
                    paused
                        ? 'Paused'
                        : finished
                        ? 'Finished'
                        : '${seconds}s · ${status == 'CHALLENGE'
                              ? 'Call LIE?'
                              : status == 'CHALLENGE_RESULT'
                              ? 'Next drop'
                              : 'To drop'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!finished && !paused)
                LinearProgressIndicator(
                  value: (seconds / duration).clamp(0.0, 1.0),
                  semanticsLabel: 'Phase time remaining',
                ),
              if (paused)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SemanticsBanner(
                    text: 'Match paused. Waiting for disconnected players to return within 60 seconds.',
                  ),
                ),
              KikikTable(
                players: players,
                viewerId: widget.playerId,
                animation: const AlwaysStoppedAnimation(0.0),
                finished: finished,
                winner: winner,
                showCardCounts: true,
                showPassing: false,
                activePlayerId: finished
                    ? null
                    : room['currentPlayerId'] as String?,
                centerContent: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      finished
                          ? Icons.emoji_events_outlined
                          : pending != null
                          ? Icons.visibility_off_outlined
                          : Icons.person_outline,
                      color: const Color(0xffdaf975),
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      finished
                          ? '${winner?['name'] ?? 'Finished'}'
                          : pending != null
                          ? name(pending['playerId'])
                          : name(room['currentPlayerId']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pending != null)
                      FittedBox(
                        child: Text(
                          '${pending['quantity']} × ${pending['rank']}',
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: Color(0xffdaf975),
                          ),
                        ),
                      )
                    else
                      Text(
                        finished ? 'Winner' : 'To play',
                        style: const TextStyle(fontSize: 13),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Hidden pile: ${room['discardCount'] ?? 0}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (finished) ...[
                SemanticsBanner(
                  text: '${winner?['name'] ?? 'Player'} wins Butbutay!',
                ),
                const SizedBox(height: 16),
              ] else if (pending != null) ...[
                SemanticsBanner(
                  text:
                      '${name(pending['playerId'])} declares ${pending['quantity']} × ${pending['rank']}. Cards stay hidden until challenged.',
                ),
                const SizedBox(height: 12),
                if (pending['playerId'] != widget.playerId)
                  FilledButton.icon(
                    onPressed: canLie ? lie : null,
                    icon: const Icon(Icons.front_hand_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'CALL LIE',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Your drop is open to challenge. You cannot call LIE on yourself.',
                    style: TextStyle(fontSize: 15),
                  ),
                const SizedBox(height: 12),
              ],
              if (result != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xff294034),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result['kind'] == 'challenged') ...[
                        SemanticsBanner(
                          text: result['truthful'] == true
                              ? 'TRUE — ${name(result['challengerId'])} picks up ${result['quantity']} card(s).'
                              : 'LIE — ${name(result['dropperId'])} picks up ${result['quantity']} card(s).',
                        ),
                        const SizedBox(height: 12),
                        if (result['cards'] is List)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final card in result['cards'] as List)
                                SizedBox(
                                  width: 48,
                                  height: 72,
                                  child: PlayingCard(
                                    card: card as Map,
                                    selected: false,
                                    enabled: false,
                                    compact: true,
                                    label: 'Challenged card',
                                    onTap: () {},
                                  ),
                                ),
                            ],
                          ),
                        if (!finished)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              '${name(result['nextPlayerId'])} plays next.',
                            ),
                          ),
                      ] else
                        Text(
                          result['kind'] == 'accepted'
                              ? finished
                                    ? 'Final drop accepted without a challenge.'
                                    : 'No challenge. ${name(result['nextPlayerId'])} drops again.'
                              : '${name(result['playerId'])} ran out of drop time. Next: ${name(result['nextPlayerId'])}.',
                        ),
                    ],
                  ),
                ),
              if (status == 'DROPPING')
                SemanticsBanner(
                  text: mine
                      ? 'Your turn. Select 1–4 cards and declare a rank.'
                      : '${name(room['currentPlayerId'])} is choosing a drop.',
                ),
              if (mine && status == 'DROPPING') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('rank-$turnId-$rank'),
                  initialValue: rank,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Declare rank (you may bluff)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in butbutayRanks)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: canDrop
                      ? (value) {
                          if (value != null) setState(() => rank = value);
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: canDrop && selected.isNotEmpty ? drop : null,
                  icon: const Icon(Icons.layers_outlined),
                  label: Text('Drop ${selected.length} as $rank'),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Your hand · ${hand.length} cards${canDrop ? ' · ${selected.length}/4 selected' : ''}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only you can see these cards. Scroll the hand to see more.',
                style: TextStyle(fontSize: 14, color: Color(0xffa7b7ad)),
              ),
              const SizedBox(height: 12),
              if (hand.isEmpty)
                Text(
                  finished ? 'Your hand is empty.' : 'Your hand is empty. The final drop must survive the challenge window.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.maxWidth / 66).floor().clamp(
                      3,
                      8,
                    );
                    final cardHeight =
                        ((constraints.maxWidth - (columns - 1) * 8) / columns) *
                        1.5;
                    final rows = (hand.length / columns).ceil();
                    return SizedBox(
                      height: math.min(290.0, rows * (cardHeight + 8)),
                      child: GridView.builder(
                        key: ValueKey('butbutay-hand-${room['code']}'),
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: 2 / 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: hand.length,
                        itemBuilder: (context, index) {
                          final card = hand[index];
                          final chosen = selected.contains(card['id']);
                          return PlayingCard(
                            key: ValueKey<String>(card['id'] as String),
                            card: card,
                            selected: chosen,
                            compact: true,
                            enabled: canDrop && (chosen || selected.length < 4),
                            label: 'Hand card ${index + 1}',
                            onTap: () => toggle(card['id'] as String),
                          );
                        },
                      ),
                    );
                  },
                ),
              if (finished) ...[
                const SizedBox(height: 20),
                if (room['hostId'] == widget.playerId) ...[
                  FilledButton(
                    onPressed: widget.busy
                        ? null
                        : () => widget.onAction('start_game', {}),
                    child: const Text('Play again'),
                  ),
                  OutlinedButton(
                    onPressed: widget.busy
                        ? null
                        : () => widget.onAction('return_to_lobby', {}),
                    child: const Text('Back to lobby'),
                  ),
                ] else
                  const Text(
                    'Waiting for the host to rematch or return to the lobby.',
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        ExpansionTile(
          key: PageStorageKey('butbutay-history-${room['code']}'),
          title: const Text('Declaration history'),
          tilePadding: EdgeInsets.zero,
          onExpansionChanged: (open) {
            if (open) focus.unfocus();
          },
          children: [
            for (final drop in (room['history'] as List? ?? []).reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${name(drop['playerId'])}: ${drop['quantity']} × ${drop['rank']}',
                ),
                subtitle: Text('${drop['outcome']}'),
              ),
          ],
        ),
        ExpansionTile(
          key: PageStorageKey('butbutay-rules-${room['code']}'),
          title: const Text('Room & rules'),
          tilePadding: EdgeInsets.zero,
          onExpansionChanged: (open) {
            if (open) focus.unfocus();
          },
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectionArea(child: Text('Room ${room['code']}')),
                  const SizedBox(height: 12),
                  const Text(
                    'All 52 cards are dealt. Drop 1–4 cards and declare their rank. Only the first opponent to call LIE within 7 seconds challenges. Only the latest drop is revealed and picked up: if false, the dropper picks it up and the challenger plays next; if true, the challenger picks it up and the dropper continues. Earlier discards always stay hidden.',
                    style: TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No challenge: the same player drops again. A final drop must survive the challenge before winning. Drop turns last 30 seconds; an idle player is skipped clockwise without losing cards. L calls LIE when available. Disconnects pause the match for up to 60 seconds; leaving or an expired seat cancels it and reopens the lobby.',
                    style: TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: widget.busy
                        ? null
                        : () => widget.onAction('leave_room', {}),
                    icon: const Icon(Icons.logout),
                    label: const Text('Leave room'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SemanticsBanner extends StatelessWidget {
  const SemanticsBanner({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
    ),
  );
}
