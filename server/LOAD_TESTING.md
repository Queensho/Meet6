# Meet6 matchmaking + WebSocket load testing

`npm run load:matchmaking` runs an isolated synthetic-user stress test against the real NestJS + PostgreSQL + Redis + Socket.IO flow.

It covers:

- authenticated Socket.IO connections
- `server:ready` latency
- concurrent ack ping latency
- real `queue:join` matchmaking calls
- real room creation and `queue:matched` delivery
- concurrent `room:join`
- one real `room:send` / `room:message` delivery per matched room
- PostgreSQL room/member/queue validation
- p50 / p95 / p99 latency reporting
- automatic cleanup of synthetic users, sessions, rooms and queue rows

Synthetic accounts use a reserved `+99988...` phone prefix and latitude `84.5`, so they are isolated from ordinary Meet6 users by the normal distance filter.

## Local / staging commands

From `server/` with the API already running on port 3100:

```bash
npm run load:matchmaking -- 100
npm run load:matchmaking -- 250
npm run load:matchmaking -- 500
```

The default Socket.IO target is:

```text
http://127.0.0.1:3100/rooms
```

The test requires `DATABASE_URL` and `REDIS_URL` because it creates disposable authenticated test accounts and removes them afterwards.

## GitHub Actions

Use the **Matchmaking WebSocket Load Test** workflow. It provides 100, 250 and 500 user choices and uploads:

- `meet6-load-report.json`
- the NestJS API log

The normal Backend E2E workflow also runs a 24-user concurrent smoke version so load-test regressions are caught on backend changes.

## Production safety

The script refuses a non-local Socket.IO hostname unless this exact opt-in is supplied:

```bash
LOAD_ALLOW_REMOTE=YES_I_KNOW
```

Do not run a 500-user production test during normal user traffic. Prefer a staging environment or a scheduled maintenance/test window. The synthetic users are geographically isolated, but the test still intentionally consumes API, PostgreSQL, Redis and Socket.IO capacity.

Example explicit remote target:

```bash
LOAD_ALLOW_REMOTE=YES_I_KNOW \
LOAD_SOCKET_BASE=https://api.meet6.com.tr/rooms \
LOAD_USERS=100 \
npm run load:matchmaking
```

For a production-domain run, the machine executing the script still needs safe access to the corresponding database and Redis for disposable test-account setup/cleanup. Running from the VPS against `127.0.0.1` avoids exposing those services.

## Useful controls

```text
LOAD_USERS=100..500
LOAD_CONNECT_RAMP_MS=8000
LOAD_QUEUE_RAMP_MS=4000
LOAD_ACK_TIMEOUT_MS=180000
LOAD_SETTLE_MS=8000
LOAD_ROOM_MESSAGES=1
LOAD_KEEP_DATA=0
LOAD_REPORT_PATH=./load-test-report.json
```

Thresholds can be adjusted with:

```text
LOAD_MIN_CONNECT_RATE=0.99
LOAD_MAX_CONNECT_P95_MS=5000
LOAD_MAX_PING_P95_MS=2000
LOAD_MAX_QUEUE_P95_MS=120000
LOAD_MAX_ROOM_JOIN_P95_MS=10000
LOAD_MAX_MESSAGE_P95_MS=5000
```

The command exits non-zero when a threshold fails. Set `LOAD_FAIL_ON_THRESHOLD=0` only when collecting exploratory measurements where a failing threshold should not fail the command.

## Reading the result

For 500 users with the normal six-person room setting, a clean run should create approximately:

```text
83 rooms
498 matched users
2 users remaining in queue
```

The report should be reviewed especially for `queueJoin.p95`, `matchedAt.p95`, connection failures, Socket.IO message latency, and server logs. A test that creates the expected rooms but has very high queue p95 is still a scalability problem and should not be treated as a successful production-capacity result.
