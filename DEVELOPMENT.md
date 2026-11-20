# Game analysis and phased delivery

The original brief is guide.md. User decisions supersede it: use Flutter instead of React/MUI and allow 1-10 players, including solo and two-player games.

## Phase 1 - Foundation (complete)

Flutter Android/iOS/web project, Node.js + Socket.IO server, validated room creation/join, membership, host transfer, room cleanup, and responsive lobby.

## Phase 2 - Authoritative quiz (implemented)

Host may start with 1-10 players. Each match uses ten shuffled, nonrepeating questions from a validated, server-only JSON bank. The pool contains the user-supplied 100 English and 100 Mathematics questions. Mixed matches sample 10 total, with no fixed subject split; the host can also select only English or Mathematics. Source option/answer keys are normalized on the server, with distinct IDs across the two banks. Source files have no difficulty ratings, so normalized difficulty is unrated. The old starter bank is no longer loaded.

Server owns question IDs, eligibility, timers, buzz order, answer validation, scoring and advancement. One valid buzz reserves an answer turn. Only that player can select a choice. Wrong answers earn no points and eliminate that player for this question. Correct answers earn 100 points. An answer timeout eliminates the player without a penalty.

There are 15 seconds of open buzzing. This clock pauses during each 15-second answer window and resumes with its unused time after a wrong answer or answer timeout. A completed question shows its outcome for four seconds, then advances automatically. The correct answer is never sent to clients or highlighted. Every new question restores eligibility for all remaining members. After ten rounds, show the scores and tied winners; host can start a new match with scores reset.

Clients send question IDs; stale/duplicate commands and nonmember/nonhost commands are rejected. Correct answers and the future deck are never serialized into client snapshots, including question results. On disconnect the player is removed; if they own the answer turn it is released. No mid-match joins. Reloading requires waiting for a new room or match flow; resumable identities are Phase 4 work.

Single-process memory remains the source of truth. First-to-buzz means server arrival order, which is affected by network latency. Restarts discard rooms. Empty rooms are deleted; active rounds refresh room activity; waiting and finished rooms expire after two idle hours.

## Phase 3 - Match presentation and options (implemented)

Implemented a centered question-focused match screen with collapsed standings and room controls, responsive live standings and tied ranks, visible turn/outcome feedback, timer/progress bars, short question transitions respecting reduced motion, keyboard controls (Space/B and 1-4), turn/outcome live regions, larger touch controls, optional generated sound cues (muted by default), synchronized host-only subject selection, and host return to the same-code lobby after results. Returning resets scores and question state and reopens the room for new players. Guests follow the transition. Rematches retain the subject. User-requested count remains fixed at 10. Difficulty filtering is deferred until the source banks include ratings; no artificial difficulty labels are introduced.

## Phase 4 - Recovery and hardening

Reconnect tokens, disconnect grace periods, action rate limits, broader automated integration tests, mobile device QA, production origin/HTTPS configuration, and deployment guide. Validate multiple simultaneous rooms and longer sessions. Persistent history and multi-server hosting require separate architecture work.

## Phase 5 - Optional modes

Bonus questions, simultaneous answers, survival and teams. Solo play already works under the same first-to-buzz rules.

## Verification

Node engine tests cover 1/2-player starts, membership/host permissions, answer secrecy, exclusive buzzes, choice validation, wrong answers, stale/duplicate commands, timers, disconnects, question reset, match completion and rematch. Dart Socket.IO checks exercise two real clients against Node, all ten rounds, score totals, answer privacy, subject selection, host permissions, lobby return, new joins and a Mathematics rematch. Seven Flutter widget tests cover name-first lobby, buzz-before-answer, subject control synchronization, keyboard actions, tied results, host controls, collapsed section persistence, and large-text phone layouts. Device runs and manual multi-browser UI acceptance remain pending. Standard JavaScript web output is supported; dependency Wasm dry-run warnings remain.

## Backend relocation

The Node backend now lives in C:/xampp/htdocs/iconcepts/faas-automation/api/abcs-game. The existing API server.js attaches its CommonJS module to the shared HTTP server (default port 8099). All game logic, JSON and tests moved there; the Flutter client stays here. npm test from this root runs the moved engine tests. Set ABCS_CLIENT_ORIGINS on the API for browser origins and SERVER_URL at Flutter build/run time. The full FAAS process and its database routes were not started during migration verification; the moved module was tested using an isolated HTTP/Express server.



Phase 3 verification: 16 backend tests, 7 widget tests, Flutter analysis, and standard JavaScript web build pass. Full-match Socket.IO integration passes. Manual browser audio, screen-reader and mobile-device checks remain pending.


## GitHub Pages deployment

The Flutter frontend deploys from jhombalz/abcs main via GitHub Actions with base href /abcs/ and HTTPS backend https://api.iconcept-faas.lguapp.com. Production defaults target that backend; debug defaults retain local port 8099. The API remains in faas-automation/api; Express and Socket.IO CORS include https://jhombalz.github.io. API-host deployment is separate from Pages. At initial deployment preparation the public API's game health and Socket.IO endpoints returned 404; upload/restart the updated backend and verify public connectivity.

## KIKIK mode (implemented)

KIKIK is a separate 3-12 player card game with mode-aware rooms, private per-seat snapshots, simultaneous direct clockwise passing with all 4×N cards dealt (one rank set per player; three players use K/Q/J), 12-second turns and AFK auto-pass, first valid four-of-a-kind claim, host rematch/lobby controls, and 60-second token-authenticated seat recovery. Quiz rules remain separate. See KIKIK.md for exact rules, network contract and intentional differences from the design proposal. The test suite now has 26 backend tests and 12 Flutter widget tests, plus a three-client Dart smoke check. General quiz reconnection and broader hardening remain Phase 4 work.
