# KIKIK — Multiplayer Card Game Design & Architecture Spec

## 1. Game Overview
**KIKIK** is a fast-paced, real-time multiplayer card-passing game built with **Flutter** (client) and **Node.js + Socket.IO** (server). Players simultaneously pass cards around a virtual table until someone collects four cards of the same rank and taps the **KIKIK** button first to win.

---

## 2. Game Rules & Deck Scaling

### Player Count
* **Minimum Players:** 3
* **Recommended Maximum Players:** 12 (limited by standard 52-card deck ranks: A, K, Q, J, 10, 9, 8, 7, 6, 5, 4, 3, 2 — up to 13 ranks total)

### Deck Composition Formula
For **$N$ players**, the active deck consists of **$N + 1$ sets of 4-of-a-kind** ($4 	imes (N + 1)$ cards total). Having one extra set keeps cards circulating so players are never stuck in a deadlock.

| Players ($N$) | Sets of 4 Needed | Total Cards in Active Deck | Example Ranks Included |
| :--- | :--- | :--- | :--- |
| **3** | 4 sets | 16 cards | K, Q, J, 10 |
| **4** | 5 sets | 20 cards | K, Q, J, 10, 9 |
| **5** | 6 sets | 24 cards | K, Q, J, 10, 9, 8 |
| **6** | 7 sets | 28 cards | K, Q, J, 10, 9, 8, 7 |

### Core Gameplay Loop
1. **Setup & Deal:**
   * Server builds the deck using $N + 1$ ranks (4 suits each: Spades, Hearts, Diamonds, Clubs).
   * Server shuffles the deck and deals **4 cards** to each player.
   * The remaining **4 cards** form a pass buffer/rotation pool (or sit between players so the pass cycle stays fluid).
2. **Simultaneous Pass Phase:**
   * Each player inspects their 4 cards and chooses **1 card** to pass to the next player (clockwise).
   * Once all players have locked in their selection (or when the turn timer expires), the server shifts all selected cards simultaneously.
   * *Note on the extra 4 cards:* You can either place the 4 remaining cards in a center rotation slot (Player $N$ passes into the buffer, and Player 1 draws from the buffer) or deal 5 cards to one starting dealer who passes first. Using a **buffer slot between Player $N$ and Player 1** keeps every player holding 4 cards at all times.
3. **Winning Condition ("KIKIK"):**
   * As soon as a player holds **4 cards of the same rank** (e.g., four Kings of any suit), their **KIKIK** button becomes active.
   * The first player to tap **KIKIK** and pass server validation wins the round.
   * *(Optional Variant — False Claim Penalty):* Tapping **KIKIK** without 4-of-a-kind locks the player out of claiming for 5 seconds or disqualifies them for the round.

---

## 3. Technical Architecture (Flutter + Socket.IO)

### Why This Stack Fits
* **Low-Latency Simultaneous Turns:** Socket.IO rooms broadcast turn state updates instantaneously once every player locks in a card.
* **Authoritative Win Resolution:** Because simultaneous passes can create two winners on the same turn, the Node.js server processes incoming `"claim_kikik"` events sequentially and awards the win to the earliest valid timestamp.
* **Cross-Platform Family Play:** A single Flutter codebase supports Android, iOS, and Web browsers using room codes.

### System Components
1. **Flutter Client (`flutter_riverpod` / `bloc` + `socket_io_client`):**
   * Lobby screen (Create Room / Join via 4-letter Room Code).
   * Game table screen showing opponent avatars, lock-in status indicators, current 4-card hand, pass countdown timer, and the **KIKIK** action button.
2. **Node.js + Socket.IO Backend:**
   * In-memory room state manager (`Map<roomCode, GameState>`).
   * Cryptographically fair Fisher-Yates shuffle on the server.
   * Server-side validation for every card selection and **KIKIK** claim.

---

## 4. Socket.IO Event Contract

### Client $ightarrow$ Server Events
| Event Name | Payload | Description |
| :--- | :--- | :--- |
| `create_room` | `{ playerName }` | Creates a new room and returns a unique `roomCode`. |
| `join_room` | `{ roomCode, playerName, playerId }` | Joins an existing room or reconnects an existing player. |
| `start_game` | `{ roomCode }` | Host starts the match (requires $\ge 3$ players). |
| `select_pass_card` | `{ roomCode, cardId }` | Player locks in the 1 card they want to pass this turn. |
| `claim_kikik` | `{ roomCode }` | Player taps the **KIKIK** button to claim 4-of-a-kind. |

### Server $ightarrow$ Client Events
| Event Name | Payload | Description |
| :--- | :--- | :--- |
| `room_updated` | `{ players, hostId, status }` | Updates lobby player list and ready states. |
| `game_started` | `{ hand, turnDeadline, playerOrder }` | Sends each player their private 4-card starting hand. |
| `player_locked` | `{ playerId }` | Shows a checkmark next to players who have picked a card to pass. |
| `turn_resolved` | `{ newHand, turnNumber, turnDeadline }` | Delivers the updated 4-card hand after simultaneous passing. |
| `game_over` | `{ winnerId, winnerName, winningHand }` | Announces the winner and reveals the winning 4-of-a-kind. |
| `invalid_claim` | `{ reason }` | Notifies a player if they tapped **KIKIK** without 4 matching ranks. |

---

## 5. Edge Cases & Implementation Checklist
* **Buffer Slot Rotation:** With $N$ players and $N + 1$ sets of 4 cards, keep 4 buffer cards in a queue (`passQueue`). On each simultaneous pass: Player 1 sends a card to Player 2, ..., Player $N$ pushes their card to the back of `passQueue`, and Player 1 pops the front card from `passQueue`. Every player always holds exactly 4 cards.
* **AFK / Slow Player Timer:** Enforce a server-side 12-second turn timer. If a player hasn't selected a card when time runs out, the server auto-passes a random card from their hand.
* **Reconnection Handling:** Persist a UUID `playerId` in Flutter's local storage (`shared_preferences`). If a player disconnects, map their new `socket.id` back to their existing seat and hand.
* **Anti-Cheat:** Never send other players' hands in `turn_resolved`—emit each player's updated hand privately to their specific `socket.id`.
