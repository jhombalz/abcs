import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GamePanel extends StatefulWidget {
  const GamePanel({
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
  State<GamePanel> createState() => _GamePanelState();
}

class _GamePanelState extends State<GamePanel> {
  final focus = FocusNode(debugLabel: 'Quiz keyboard controls');
  String? questionId;
  String? selected;
  @override
  void initState() {
    super.initState();
    questionId = widget.room['question']?['id'] as String?;
  }

  @override
  void didUpdateWidget(covariant GamePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextId = widget.room['question']?['id'] as String?;
    if (nextId != questionId) {
      questionId = nextId;
      selected = null;
    }
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  bool get canBuzz =>
      !widget.busy &&
      widget.room['status'] == 'QUESTION_ACTIVE' &&
      (widget.room['eligible'] as List? ?? []).contains(widget.playerId);
  bool get canAnswer =>
      !widget.busy &&
      widget.room['status'] == 'ANSWERING' &&
      widget.room['answeringId'] == widget.playerId;
  void buzz() {
    if (canBuzz) {
      widget.onAction('buzz', {'questionId': widget.room['question']['id']});
    }
  }

  void answer(dynamic choice) {
    if (!canAnswer) return;
    setState(() => selected = '$choice');
    widget.onAction('submit_answer', {
      'questionId': widget.room['question']['id'],
      'answer': choice,
    });
  }

  KeyEventResult handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (canBuzz &&
        [
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.keyB,
        ].contains(event.logicalKey)) {
      buzz();
      return KeyEventResult.handled;
    }
    const numbers = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];
    const keypad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
    ];
    final index = numbers.contains(event.logicalKey)
        ? numbers.indexOf(event.logicalKey)
        : keypad.indexOf(event.logicalKey);
    if (canAnswer && index >= 0) {
      answer((widget.room['question']['choices'] as List)[index]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final status = room['status'];
    final question = room['question'] as Map?;
    final players = List<Map>.from(room['players'] as List)
      ..sort((a, b) {
        final score = (b['score'] as int).compareTo(a['score'] as int);
        return score != 0
            ? score
            : (a['name'] as String).compareTo(b['name'] as String);
      });
    final mine = room['answeringId'] == widget.playerId;
    final eligible = (room['eligible'] as List? ?? []).contains(
      widget.playerId,
    );
    final answering = players
        .where((p) => p['id'] == room['answeringId'])
        .firstOrNull;
    final finished = status == 'GAME_FINISHED';
    final result = room['result'] as Map?;
    final feedback = room['feedback'] as Map?;
    final feedbackPlayer = players
        .where((p) => p['id'] == feedback?['playerId'])
        .firstOrNull;
    final seconds = (room['secondsLeft'] as num? ?? 0).toInt();
    final duration = status == 'QUESTION_FINISHED' ? 4 : 15;
    final urgent = seconds <= 5 && status != 'QUESTION_FINISHED';
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final isHost = room['hostId'] == widget.playerId;
    final outcome = status == 'QUESTION_FINISHED';
    final hint = outcome
        ? 'Round complete. The next question is on its way.'
        : status == 'ANSWERING'
        ? mine
              ? 'Your turn! Choose one answer.'
              : '${answering?['name'] ?? 'Another player'} is answering.'
        : eligible
        ? 'Your buzzer is open. Be first!'
        : 'You are out for this question. You can buzz again next round.';
    final questionCard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (finished) ...[
          const Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Color(0xffdaf975),
          ),
          const SizedBox(height: 16),
          const Text(
            'Match finished!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              players.isEmpty
                  ? 'Thanks for playing.'
                  : '${players.where((p) => p['score'] == players.first['score']).length > 1
                        ? 'Joint winners'
                        : players.length == 1
                        ? 'Your result'
                        : 'Winner'}: ${players.where((p) => p['score'] == players.first['score']).map((p) => p['name']).join(', ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${players.where((p) => p['id'] == widget.playerId).firstOrNull?['score'] ?? 0} points earned',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (isHost) ...[
            FilledButton.icon(
              onPressed: widget.busy
                  ? null
                  : () => widget.onAction('start_game', {}),
              icon: const Icon(Icons.replay),
              label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Play again'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.busy
                  ? null
                  : () => widget.onAction('return_to_lobby', {}),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Back to lobby'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Back to lobby keeps your room code and players, resets scores, and lets you invite more friends.',
              textAlign: TextAlign.center,
            ),
          ] else
            const Text(
              'Waiting for the host to play again or return everyone to the lobby.',
              textAlign: TextAlign.center,
            ),
        ] else if (question != null) ...[
          Text(
            'Question ${room['round']} / ${room['totalRounds']} · ${question['category']}',
            style: const TextStyle(fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: ((room['round'] as num) / (room['totalRounds'] as num))
                .clamp(0.0, 1.0),
            minHeight: 4,
            semanticsLabel: 'Match progress',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                urgent ? Icons.timer : Icons.timer_outlined,
                color: urgent ? Colors.orangeAccent : const Color(0xffdaf975),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$seconds'
                  's · ${status == 'ANSWERING'
                      ? 'Answer timer'
                      : outcome
                      ? 'Next question'
                      : 'Buzz timer'}',
                  style: TextStyle(
                    color: urgent
                        ? Colors.orangeAccent
                        : const Color(0xffdaf975),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (seconds / duration).clamp(0.0, 1.0),
            color: urgent ? Colors.orangeAccent : null,
            semanticsLabel: status == 'ANSWERING'
                ? 'Answer time remaining'
                : 'Time remaining',
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Align(
              key: ValueKey(question['id']),
              alignment: Alignment.centerLeft,
              child: Text(
                '${question['question']}',
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.35,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          for (final (index, choice) in (question['choices'] as List).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                label: 'Choice ${index + 1}',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(14),
                    backgroundColor: selected == '$choice'
                        ? const Color(0xff2c3e30)
                        : null,
                  ),
                  onPressed: canAnswer ? () => answer(choice) : null,
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$choice',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xffe0e8da),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          if (status == 'QUESTION_ACTIVE')
            FilledButton.icon(
              onPressed: canBuzz ? buzz : null,
              icon: const Icon(Icons.touch_app_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'BUZZ!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              hint,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          if (!outcome)
            const Text(
              'Keyboard: Space or B to buzz · 1–4 to answer',
              style: TextStyle(fontSize: 12, color: Color(0xffa7b7ad)),
            ),
          if (feedback != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: feedback['kind'] == 'correct'
                        ? const Color(0xff30432a)
                        : const Color(0xff2a3531),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${feedbackPlayer?['name'] ?? 'Player'}: ${feedback['message']}',
                  ),
                ),
              ),
            ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${result['reason']}'),
            ),
        ],
      ],
    );
    final board = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff111e19),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            finished ? 'FINAL STANDINGS' : 'LIVE STANDINGS',
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: Color(0xffdaf975),
            ),
          ),
          const SizedBox(height: 12),
          for (final player in players)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${players.indexWhere((p) => p['score'] == player['score']) + 1}',
                      style: const TextStyle(
                        fontSize: 19,
                        color: Color(0xffdaf975),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${player['name']}${player['id'] == widget.playerId ? ' (you)' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (!finished && player['id'] == room['answeringId'])
                          const Text(
                            'Answering',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xffdaf975),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${player['score']} pts',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const Divider(),
          const Text(
            '+100 correct · 0 incorrect\nAnswers stay hidden.',
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: Color(0xffa7b7ad),
            ),
          ),
        ],
      ),
    );
    return Focus(
      autofocus: true,
      focusNode: focus,
      onKeyEvent: handleKey,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 760
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: questionCard),
                    const SizedBox(width: 32),
                    Expanded(child: board),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [questionCard, const SizedBox(height: 28), board],
                ),
        ),
      ),
    );
  }
}
