# KIKIK mode

KIKIK is a separate game in Buzz Club. The original proposal is in kikik_game_design.md; this document records the implemented rules and protocol.

## Play

Enter a display name and press OK. Choose KIKIK before creating a room. Other players join using the same six-digit code; the room determines their game mode automatically. KIKIK requires 3-12 connected players. Quiz still supports 1-10.

The server selects exactly N ranks for N players, using Kings, Queens, Jacks, then 10, 9, 8, and so on as players increase. Three players use exactly four Kings, four Queens and four Jacks (12 cards); four players add the four 10s (16 cards). Each rank has all four suits. The full 4×N-card deck is shuffled using crypto.randomInt and every card is dealt, four per player. No draw pile or buffer remains. Every player chooses one card, then presses Lock card to pass. Locked selections cannot change. All cards pass simultaneously when everyone locks or after 12 seconds. Unselected hands auto-pass a random card. Every player receives the card passed by the previous seat; the last seat passes directly to the first. Each player always holds four cards.

Four matching ranks unlock KIKIK. The first valid claim received by the server wins. Client timestamps are not used. A matching starting hand can claim immediately. A player may still claim a matching hand after locking a pass, until that turn resolves. Claims/selections carry the current turn ID; requests for an old turn or rematch are rejected. Invalid claims earn no win; the optional false-claim penalty is not enabled.

Keyboard: 1-4 selects a card, Enter locks it, K claims. The table and room/rules panels are collapsed to keep the hand and actions prominent. Opponents show only connection and lock status. Only the winning hand is revealed at the end. The host can rematch or return everyone to the same lobby. No quiz question data or scoring is involved.

A round ends without a winner at the 200-turn limit. No automatic reshuffle changes anyone's hand mid-round.

## Reconnection and leaving

The server creates stable seat IDs and random 256-bit reconnect tokens. Tokens are returned only in create/join/resume acknowledgments; never in room updates. Reconnecting requires both the room code and token, not a supplied player ID. Connected seats cannot be taken over. Tokens are revoked on explicit leave, seat expiry, or room cleanup. Reservations last 60 seconds after disconnect; disconnected hands continue auto-passing on the normal timer.

Web saves the credential in tab-scoped sessionStorage. This supports reloads and keeps separate tabs from overwriting each other's seats. A duplicated tab cannot take over an already-connected seat. Native Flutter saves the credential with shared_preferences. If storage is unavailable, reconnect can still work in the same running app, but restoration after reload may be unavailable. Credentials are scoped to the configured backend URL.

A disconnected host role moves to another connected player. An explicit leave or expired seat during play aborts the current round and returns the remaining players to the lobby; changing the deck mid-round is avoided. When fewer than three connected players remain, invite more before starting. A server restart loses in-memory seats, hands and credentials. Quiz disconnect behavior remains immediate removal; general quiz recovery is still Phase 4 work.

## Backend and protocol

Backend files remain in faas-automation/api/abcs-game. No additional Node dependencies are required. The existing server.js still calls require("./abcs-game")(http, app), sharing port 8099 and /socket.io.

- create_room: { name, mode: "quiz" | "kikik" }. Quiz is the default for older clients.
- join_room: { name, code }. The existing room determines mode.
- resume_room: { code, token } restores a reserved KIKIK seat.
- start_game / return_to_lobby: host-only, dispatched to the room's engine.
- select_pass_card: { turnId, cardId }. Ownership and one-selection-per-turn are validated.
- claim_kikik: { turnId }. The server checks the current hand.
- leave_room: permanently leaves the seat and revokes its credential.
- room_updated: emitted separately to each connected member. Includes public table information plus only that member's hand, canClaim flag, viewerId and current turn. Other players hands, internal selections and tokens are excluded. Settings include dealRule: "all_dealt" so new clients can detect an outdated API. A finished snapshot includes the winning hand only.

Successful create/join/resume acknowledgments include { ok, room, playerId, resume: { code, token } } for KIKIK. Other successful actions include { ok, room, playerId }. Errors use { ok: false, error }. No unfiltered room object is broadcast. Quiz snapshots still omit correct answers and its future deck.

The health endpoint /abcs-game/health advertises modes: ["quiz", "kikik"]. If the production host is still running the old backend, deploy the updated complete abcs-game folder and restart Node before playing KIKIK. The frontend detects an old quiz-only create response and explains the required backend update.

## Verification

npm test from the abcs root runs 26 backend tests, including a three-client WebSocket/Socket.IO integration test. Tests cover scaled decks, unique cards, direct clockwise passing and last-to-first wraparound, card conservation, private views, membership/host permissions, duplicate/stale actions, claims, timeouts, turn limits, reconnect authentication/expiry, mode isolation and quiz regressions. Tests use Node.js 22+ for the built-in WebSocket test client.

Flutter has 12 widget tests covering existing quiz flows plus KIKIK mode selection, player minimums, selection/locking, keyboard claims, busy states, winners, and large-text phone layouts.

For a running API, from client:

```sh
dart run tool/check_kikik.dart http://localhost:8099
```

This creates three real Dart clients, checks private hands, resolves a simultaneous pass, and reconnects one seat. For manual acceptance, open three browser tabs, create one KIKIK room, join the other two, start, lock one card in each tab, reload a tab to test its reservation, and continue until someone can claim. Browser audio, physical-device interaction and production proxy behavior still need manual checks.

## Circular table presentation

Seats appear around an oval table, with the viewer at the bottom and only face-down cards at other seats. The center shows that all cards are dealt. After an authoritative turn update, face-down cards animate directly clockwise between seats, including the last-to-first pass. Animations do not delay valid selections or claims. The new card highlights briefly and occupies the outgoing card slot; retained cards stay in their slots, including keyboard numbering. Reduced-motion settings skip the animation.

When KIKIK is claimed, each viewer keeps their own four cards in place. The winner is marked at their seat and their winning hand is revealed in a separate panel below the viewer hand. Other hands remain hidden. The all-dealt rules require the updated backend. The lobby disables starting on older APIs until settings.dealRule advertises all_dealt. Deploy the complete updated abcs-game folder and restart Node; no server.js changes are needed.
