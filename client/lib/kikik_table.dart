import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Uses public seat metadata only. Opponent card faces never enter this widget.
class KikikTable extends StatelessWidget {
  const KikikTable({
    super.key,
    required this.players,
    required this.viewerId,
    required this.animation,
    required this.finished,
    required this.winner,
  });
  final List<Map> players;
  final String? viewerId;
  final Animation<double> animation;
  final bool finished;
  final Map? winner;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(680.0, constraints.maxWidth);
      final compact = width < 420;
      final crowded = players.length >= 9;
      final height = crowded
          ? 500.0
          : players.length >= 7
          ? 400.0
          : compact
          ? 300.0
          : 320.0;
      final seatWidth = compact
          ? crowded
                ? 48.0
                : players.length >= 6
                ? 62.0
                : 80.0
          : 96.0;
      final seatHeight = compact && crowded ? 72.0 : 80.0;
      final center = Offset(width / 2, height / 2);
      final rx = (width - seatWidth) / 2 - 4;
      final ry = (height - seatHeight) / 2 - 4;
      final ownIndex = math.max(
        0,
        players.indexWhere((p) => p['id'] == viewerId),
      );
      Offset seat(int index) {
        final angle =
            math.pi / 2 +
            ((index - ownIndex + players.length) % players.length) *
                math.pi *
                2 /
                players.length;
        return center + Offset(math.cos(angle) * rx, math.sin(angle) * ry);
      }

      final seats = [for (var i = 0; i < players.length; i++) seat(i)];
      final centerWidth = compact
          ? math.min(154.0, width * (players.length == 3 ? 0.28 : 0.38))
          : 260.0;
      return Center(
        child: SizedBox(
          width: width,
          height: height,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final moving =
                  !finished && animation.status == AnimationStatus.forward;
              final t = Curves.easeInOutCubic.transform(animation.value);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: seatWidth / 2,
                    right: seatWidth / 2,
                    top: seatHeight / 2,
                    bottom: seatHeight / 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(height),
                        color: const Color(0xff15362e),
                        border: Border.all(
                          color: const Color(0xff34594a),
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (moving)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _PassTrails(seats, center)),
                      ),
                    ),
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: centerWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (finished && winner != null) ...[
                            const Icon(
                              Icons.emoji_events_outlined,
                              color: Color(0xffdaf975),
                              size: 26,
                            ),
                            const SizedBox(height: 4),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                '${winner!['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xffdaf975),
                                ),
                              ),
                            ),
                            const Text(
                              'KIKIK!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xffdaf975),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.sync,
                              size: 32,
                              color: Color(0xffbbd8c2),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'PASS CLOCKWISE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.7,
                                color: Color(0xffbbd8c2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'All cards dealt',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xffbbd8c2),
                              ),
                            ),
                            if (moving)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Passing…',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xffdaf975),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  for (var i = 0; i < players.length; i++)
                    Positioned(
                      key: ValueKey('kikik-seat-${players[i]['id']}'),
                      left: seats[i].dx - seatWidth / 2,
                      top: seats[i].dy - seatHeight / 2,
                      width: seatWidth,
                      height: seatHeight,
                      child: _TableSeat(
                        player: players[i],
                        own: players[i]['id'] == viewerId,
                        winner: finished && winner?['id'] == players[i]['id'],
                        compact: compact && crowded,
                      ),
                    ),
                  if (moving && seats.isNotEmpty) ...[
                    for (var i = 0; i < seats.length; i++)
                      _travel(
                        seats[i],
                        seats[(i + 1) % seats.length],
                        center,
                        t,
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      );
    },
  );

  Widget _travel(Offset start, Offset end, Offset center, double t) {
    final mid = Offset.lerp(Offset.lerp(start, end, 0.5)!, center, 0.18)!;
    final position =
        start * ((1 - t) * (1 - t)) + mid * (2 * (1 - t) * t) + end * (t * t);
    return Positioned(
      left: position.dx - 11,
      top: position.dy - 16,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Transform.rotate(
            angle: (t - 0.5) * 0.5,
            child: const HiddenCard(width: 22, height: 32),
          ),
        ),
      ),
    );
  }
}

class _TableSeat extends StatelessWidget {
  const _TableSeat({
    required this.player,
    required this.own,
    required this.winner,
    required this.compact,
  });
  final Map player;
  final bool own;
  final bool winner;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final connected = player['connected'] == true;
    final locked = player['locked'] == true;
    final name = '${player['name']}';
    return Tooltip(
      message:
          '$name${own ? ' (you)' : ''} · ${winner
              ? 'Winner'
              : !connected
              ? 'Reconnecting'
              : locked
              ? 'Card locked'
              : 'Choosing'}',
      child: Semantics(
        label:
            '$name${own ? ', your seat' : ''}, ${winner
                ? 'winner'
                : !connected
                ? 'reconnecting'
                : locked
                ? 'card locked'
                : 'at the table'}, four cards',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 28 : 32,
                height: compact ? 28 : 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: winner
                      ? const Color(0xffdaf975)
                      : own
                      ? const Color(0xff355347)
                      : const Color(0xff223a32),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: winner || own
                        ? const Color(0xffdaf975)
                        : const Color(0xff6e8d7e),
                    width: winner ? 3 : 1,
                  ),
                ),
                child: winner
                    ? const Icon(
                        Icons.emoji_events,
                        size: 19,
                        color: Color(0xff173326),
                      )
                    : !connected
                    ? const Icon(Icons.wifi_off, size: 15)
                    : Text(
                        name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  own ? 'You' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              if (winner)
                const Text(
                  'WINNER',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    color: Color(0xffdaf975),
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 4; i++)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1),
                        child: HiddenCard(width: 6, height: 11),
                      ),
                    if (locked)
                      const Padding(
                        padding: EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xffdaf975),
                          size: 12,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HiddenCard extends StatelessWidget {
  const HiddenCard({super.key, required this.width, required this.height});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff365b8a),
        borderRadius: BorderRadius.circular(width > 20 ? 5 : 1),
        border: Border.all(
          color: const Color(0xffd9e5e4),
          width: width > 20 ? 1.5 : 0.6,
        ),
      ),
      child: width > 20
          ? Center(
              child: Text(
                'K',
                style: TextStyle(
                  color: const Color(0xffe1edec),
                  fontSize: width * 0.48,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : null,
    ),
  );
}

class _PassTrails extends CustomPainter {
  _PassTrails(this.seats, this.center);
  final List<Offset> seats;
  final Offset center;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x449ed9ad)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    void draw(Offset start, Offset end) {
      final mid = Offset.lerp(Offset.lerp(start, end, 0.5)!, center, 0.18)!;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy),
        paint,
      );
    }

    for (var i = 0; i < seats.length; i++) {
      draw(seats[i], seats[(i + 1) % seats.length]);
    }
  }

  @override
  bool shouldRepaint(covariant _PassTrails oldDelegate) =>
      oldDelegate.seats != seats || oldDelegate.center != center;
}
