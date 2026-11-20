import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kikik_table.dart';

class KikikPanel extends StatefulWidget {
  const KikikPanel({
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
  State<KikikPanel> createState() => _KikikPanelState();
}

class _KikikPanelState extends State<KikikPanel>
    with SingleTickerProviderStateMixin {
  final focus = FocusNode(debugLabel: 'KIKIK card controls');
  String? selected;
  String? turnId;
  late final AnimationController passes;
  List<Map> displayedHand = [];
  String? receivedId;
  String? matchId;
  int lastTurn = 0;
  @override
  void initState() {
    super.initState();
    turnId = widget.room['turnId'] as String?;
    matchId = widget.room['matchId'] as String?;
    lastTurn = (widget.room['turnNumber'] as num? ?? 0).toInt();
    displayedHand = List<Map>.from(widget.room['hand'] as List? ?? []);
    passes = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    passes.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => receivedId = null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      passes.stop();
      receivedId = null;
    }
  }

  @override
  void didUpdateWidget(covariant KikikPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.room['turnId'] as String?;
    final nextMatch = widget.room['matchId'] as String?;
    final nextTurn = (widget.room['turnNumber'] as num? ?? 0).toInt();
    final newHand = List<Map>.from(widget.room['hand'] as List? ?? []);
    final sameRound = nextMatch == matchId;
    final incoming = newHand
        .where((card) => !displayedHand.any((old) => old['id'] == card['id']))
        .toList();
    final outgoing = displayedHand
        .where((card) => !newHand.any((next) => next['id'] == card['id']))
        .toList();
    if (sameRound &&
        displayedHand.length == 4 &&
        newHand.length == 4 &&
        incoming.length <= 1 &&
        incoming.length == outgoing.length) {
      final remaining = {for (final card in newHand) card['id']: card};
      // Keep retained cards in their original slots; the received card fills the gap.
      displayedHand = [
        for (final card in displayedHand)
          remaining[card['id']] ?? incoming.single,
      ];
    } else {
      displayedHand = newHand;
    }
    if (next != turnId) {
      turnId = next;
      selected = null;
    }
    if (sameRound &&
        nextTurn == lastTurn + 1 &&
        widget.room['status'] == 'PASSING' &&
        !MediaQuery.disableAnimationsOf(context)) {
      receivedId = incoming.length == 1
          ? incoming.single['id'] as String
          : null;
      passes.forward(from: 0);
    } else if (!sameRound || widget.room['status'] != 'PASSING') {
      passes.stop();
      receivedId = null;
    }
    lastTurn = nextTurn;
    matchId = nextMatch;
  }

  @override
  void dispose() {
    focus.dispose();
    passes.dispose();
    super.dispose();
  }

  bool get locked => (widget.room['players'] as List).any(
    (p) => p['id'] == widget.playerId && p['locked'] == true,
  );
  bool get canSelect =>
      !widget.busy && !locked && widget.room['status'] == 'PASSING';
  void choose(String id) {
    if (canSelect) setState(() => selected = id);
  }

  void pass() {
    if (!canSelect || selected == null) return;
    widget.onAction('select_pass_card', {
      'turnId': widget.room['turnId'],
      'cardId': selected,
    });
  }

  void claim() {
    if (!widget.busy &&
        widget.room['status'] == 'PASSING' &&
        widget.room['canClaim'] == true) {
      widget.onAction('claim_kikik', {'turnId': widget.room['turnId']});
    }
  }

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.keyK &&
        widget.room['canClaim'] == true) {
      claim();
      return KeyEventResult.handled;
    }
    const keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];
    final index = keys.indexOf(event.logicalKey);
    final hand = displayedHand;
    if (canSelect && index >= 0 && index < hand.length) {
      choose(hand[index]['id'] as String);
      return KeyEventResult.handled;
    }
    if (canSelect &&
        selected != null &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      pass();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _cards(List<Map> hand, {bool winning = false}) => LayoutBuilder(
    builder: (context, constraints) {
      final gap = winning ? 4.0 : 8.0;
      final width = math.min(
        winning ? 54.0 : 140.0,
        (constraints.maxWidth - gap * 3) / 4,
      );
      return AnimatedBuilder(
        animation: passes,
        builder: (context, _) => Wrap(
          key: ValueKey(winning ? 'winning-hand' : 'own-hand'),
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: 12,
          children: [
            for (final (index, card) in hand.indexed)
              SizedBox(
                width: width,
                height: width * 1.5,
                child: PlayingCard(
                  card: card,
                  selected:
                      !winning &&
                      selected == card['id'] &&
                      widget.room['status'] != 'GAME_FINISHED',
                  received:
                      !winning &&
                      passes.isAnimating &&
                      receivedId == card['id'],
                  compact: winning,
                  enabled: !winning && canSelect,
                  label: winning
                      ? 'Winning card ${index + 1}'
                      : 'Card ${index + 1}',
                  onTap: () => choose(card['id'] as String),
                ),
              ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final finished = room['status'] == 'GAME_FINISHED';
    final players = List<Map>.from(room['players'] as List);
    final hand = displayedHand;
    final winner = room['winner'] as Map?;
    final seconds = room['secondsLeft'] as num? ?? 0;
    final claimReady = room['canClaim'] == true && !finished;
    final isHost = room['hostId'] == widget.playerId;
    final order = players.indexWhere((p) => p['id'] == widget.playerId);
    final nextPlayer = players.isEmpty || order < 0
        ? null
        : players[(order + 1) % players.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          autofocus: true,
          focusNode: focus,
          onKeyEvent: onKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SizedBox(
                      height: 40,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'KIKIK',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: Color(0xffdaf975),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Turn ${room['turnNumber']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        finished ? 'Done' : '${seconds.toInt()}s',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: seconds <= 3 ? Colors.orangeAccent : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!finished)
                LinearProgressIndicator(
                  value: (seconds / 12).clamp(0.0, 1.0),
                  semanticsLabel: 'Time to select a card to pass',
                )
              else
                const SizedBox(height: 4),
              const SizedBox(height: 12),
              KikikTable(
                players: players,
                viewerId: widget.playerId,
                animation: passes,
                finished: finished,
                winner: winner,
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Your hand',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Only you can see these cards.',
                style: const TextStyle(fontSize: 15, color: Color(0xffa7b7ad)),
              ),
              const SizedBox(height: 22),
              _cards(hand),
              const SizedBox(height: 22),
              if (finished && winner != null)
                Container(
                  key: const ValueKey('winner-reveal'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff213d2e),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffdaf975)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${winner['name']} called KIKIK!',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Color(0xffdaf975),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Winning hand',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      _cards(
                        List<Map>.from(winner['hand'] as List),
                        winning: true,
                      ),
                    ],
                  ),
                ),
              if (finished && winner != null) const SizedBox(height: 16),
              if (finished && winner == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('${room['notice'] ?? 'No winner this round.'}'),
                ),
              if (!finished) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    claimReady
                        ? 'Four of a kind! Call KIKIK now.'
                        : passes.isAnimating
                        ? 'One card passed. One card received.'
                        : locked
                        ? 'Card locked. Waiting for the table…'
                        : 'Choose one card, then lock it to pass.',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: !widget.busy && claimReady ? claim : null,
                  icon: const Icon(Icons.front_hand_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'KIKIK!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: canSelect && selected != null ? pass : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      locked ? 'Card locked' : 'Lock card to pass',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  locked
                      ? '${players.where((p) => p['locked'] == true).length} / ${players.length} players locked in'
                      : 'Passing clockwise to ${nextPlayer?['name'] ?? 'the next player'}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ] else if (isHost) ...[
                FilledButton.icon(
                  onPressed: widget.busy
                      ? null
                      : () => widget.onAction('start_game', {}),
                  icon: const Icon(Icons.replay),
                  label: const Text('Play again'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: widget.busy
                      ? null
                      : () => widget.onAction('return_to_lobby', {}),
                  child: const Text('Back to lobby'),
                ),
              ] else
                const Text(
                  'Waiting for the host to start again or return to the lobby.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ExpansionTile(
          key: PageStorageKey('kikik-table-${room['code']}'),
          title: Text('Table · ${players.length} players'),
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (open) {
            if (open) focus.unfocus();
          },
          children: [
            for (final (index, player) in players.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(
                  '${player['name']}${player['id'] == widget.playerId ? ' (you)' : ''}',
                ),
                subtitle: Text(
                  player['connected'] != true
                      ? 'Reconnecting · seat reserved for 60s'
                      : player['locked'] == true && !finished
                      ? 'Card locked'
                      : 'At the table',
                ),
                trailing: Icon(
                  player['connected'] != true
                      ? Icons.wifi_off
                      : player['locked'] == true && !finished
                      ? Icons.check_circle_outline
                      : Icons.person_outline,
                  size: 20,
                ),
              ),
          ],
        ),
        ExpansionTile(
          key: PageStorageKey('kikik-help-${room['code']}'),
          title: const Text('Room & rules'),
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
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
                    'There is one four-card rank set per player. Three players use Kings, Queens and Jacks; each extra player adds the next rank (10, 9, and so on). All cards are shuffled and dealt, four per player. No cards remain in a deck. Selected cards pass together clockwise, directly from the last player back to the first. Turns resolve when everyone locks or after 12 seconds, with random auto-passes for unselected hands.',
                    style: TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Four cards of the same rank unlock KIKIK. The first valid claim received by the server wins. Keyboard: 1–4 to select, Enter to lock, K to claim. The round ends without a winner after 200 turns.',
                    style: TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Reconnect within 60 seconds to keep your seat. Leaving or an expired seat ends the current round and returns everyone to the lobby.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: widget.busy
                        ? null
                        : () => widget.onAction('leave_room', {}),
                    icon: const Icon(Icons.logout, size: 18),
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

class PlayingCard extends StatelessWidget {
  const PlayingCard({
    super.key,
    required this.card,
    required this.selected,
    required this.enabled,
    required this.label,
    required this.onTap,
    this.received = false,
    this.compact = false,
  });
  final Map card;
  final bool selected;
  final bool enabled;
  final String label;
  final VoidCallback onTap;
  final bool received;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    const suits = {'spades': '♠', 'hearts': '♥', 'diamonds': '♦', 'clubs': '♣'};
    final color = ['hearts', 'diamonds'].contains(card['suit'])
        ? const Color(0xffb52d48)
        : const Color(0xff15231c);
    return Semantics(
      label:
          '$label: ${card['rank']} of ${card['suit']}${received ? ', just received' : ''}',
      selected: selected,
      button: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: OutlinedButton(
          onPressed: enabled ? onTap : null,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.all(compact ? 2 : 8),
            backgroundColor: selected
                ? const Color(0xffdaf975)
                : const Color(0xfff1f4ee),
            disabledBackgroundColor: const Color(0xffe4e9e1),
            side: BorderSide(
              color: selected
                  ? const Color(0xffdaf975)
                  : received
                  ? const Color(0xff55dcc7)
                  : Colors.transparent,
              width: 3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 5 : 12),
            ),
          ),
          child: FittedBox(
            child: Column(
              children: [
                Text(
                  '${card['rank']}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  suits[card['suit']] ?? '',
                  style: TextStyle(fontSize: 30, color: color),
                ),
                if (selected) Icon(Icons.check, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
