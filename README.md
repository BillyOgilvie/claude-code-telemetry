# claude-code-grafana

Track Claude Code token use and estimated spend in Grafana, using Claude Code's built-in OpenTelemetry export. Three dashboards: month-to-date spend, usage with what-if pricing for other models, and a token breakdown by type, agent, session and model.

Costs are Claude Code's own estimate at API list prices, not an invoice. Claude Code only: claude.ai chat is not included.

```
Claude Code --OTLP/HTTP :4318--> grafana/otel-lgtm (collector, Prometheus, Loki, Grafana)
```

## Setup

**1. Start the stack** (needs Docker)

```bash
cp .env.example .env    # optional, defaults work
docker compose up -d
```

Grafana: <http://localhost:3300> (login `admin` / `admin`, change it). First start takes about a minute.

**2. Point Claude Code at it.** Merge the `env` block from `settings.example.json` into your user settings, then restart Claude Code:

| OS | File |
|---|---|
| macOS, Linux, WSL | `~/.claude/settings.json` |
| Windows | `%USERPROFILE%\.claude\settings.json` |

To also record prompt text, responses and tool details, use `settings.example.log-prompts-and-tools.json` instead (see Notes before you do). Every install needs its own copy (Windows and WSL are separate). If the stack is on another machine or you changed `OTLP_HTTP_PORT`, edit the endpoint. Repository-level `.claude/settings.json` is ignored for these variables.

**3. Import the dashboards.** Grafana: Dashboards, New, Import, upload each file in `dashboards/`, pick the Prometheus and Loki data sources.

**4. Send a prompt.** Data appears within about a minute.

## Using the dashboards

- **Spend** (`claude-code-spend-dashboard.json`): set the monthly budget in the box at the top and keep the time range on "This month so far". The month is UTC.
- **Token breakdown** (`claude-code-tokens-dashboard.json`): input, output, cache read and cache write tokens and their cost, split by agent / sub agent, session and model. Claude Code reports only a total cost per request, so no prices are entered: each model's input price is derived from the reported cost, and the other types use fixed price ratios (output 5x, cache read 0.1x, cache write 1.25x of input; hidden dashboard variables `out_mult`, `cache_read_mult`, `cache_write_mult`, editable under dashboard settings, Variables). The per-type costs therefore add up to the reported cost, and the "Derived prices per model" table shows the resulting USD per 1M tokens. Premium requests (fast mode, long context) nudge the derived price slightly above list. Real sub agent names need `OTEL_LOG_TOOL_DETAILS` (see Notes); otherwise they show as `custom`.
- **Usage** (`claude-code-usage-dashboard.json`): the four `USD/1M` boxes default to placeholder prices. Enter the target model's real per-million prices to get a what-if cost. Cache write is normally the input price if the provider has no separate write charge. To keep your prices, save the dashboard and tick "Update default variable values".

## Tagging sessions (optional)

Splits spend by project, task and run. Untagged sessions show as `untagged`.

Source `scripts/claude-tag.sh` (bash, zsh) or `scripts/claude-tag.ps1` (PowerShell) from your shell profile. It adds a `cct` command that starts Claude Code with tags:

```bash
cct myapp fix-login 2                # project task run
cct myapp fix-login                  # run defaults to 1
cct                                  # project = repo or folder name, task = untagged, run = 1
cct myapp fix-login 2 -- --resume    # arguments after -- go to claude
```

Plain `claude` is unchanged and stays untagged. Without the script: `OTEL_RESOURCE_ATTRIBUTES="project=myapp,task=fix-login,run=1" claude`.

Values may only contain letters, digits, `.`, `_` and `-`; the script cleans anything else, but a hand-written value with a space or comma makes Claude Code drop all the tags. IDE extension sessions are untagged. Tags cannot be added to past data.

## Notes

- **Retention:** 90 days by default (`RETENTION` in `.env`). A monthly view needs at least 31. The spend dashboard has a "Metric history" panel that goes red if there is less than a month. The Prometheus flag is documented by the image; I did not verify the Loki one takes effect.
- **Security:** OTLP has no authentication and telemetry includes your account email. Ports bind to `127.0.0.1` by default. Set `OTLP_BIND=0.0.0.0` only on a trusted network, and never expose these ports to the internet.
- **Prompts and tool details:** off by default, so only token counts, costs and metadata are exported. `settings.example.log-prompts-and-tools.json` turns on `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_ASSISTANT_RESPONSES` and `OTEL_LOG_TOOL_DETAILS`. That stores your prompts, Claude's replies, shell commands and file paths in Loki, readable by anyone with Grafana access, and may capture secrets you paste or code you handle. It also shows real agent, skill and MCP names on the token and cost counters instead of `custom`. Don't use it on a shared or work stack without approval. The dashboards don't need it. `OTEL_LOG_RAW_API_BODIES` (full conversation history) is deliberately not included.
- **Image:** `grafana/otel-lgtm` is meant for development and testing by its authors. Tested with `latest` on 2026-11-01; pin a tag if you want stability.
- **Platforms:** developed on Windows and WSL with a Raspberry Pi host. macOS should work but is untested.

## Troubleshooting

- **No data:** run `claude --debug-file claude-otel.log`, send a prompt, exit, then search the log for `3P telemetry`. You want `First metrics export: SUCCESS`. No such lines means the settings file was not read (wrong install or file).
- **Port reachable?** Expect `200` (use `curl.exe` in PowerShell):
  `curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:4318/v1/metrics -H "Content-Type: application/json" -d "{}"`
- **Port in use:** change it in `.env`, then `docker compose up -d`.
- **Remote machine cannot connect:** `OTLP_BIND` is still `127.0.0.1`, or the endpoint host is wrong.
- **Panels empty after starting a new project:** set the project, task and run dropdowns to All.
- **No project/task/run labels:** the session started without the wrapper or env var.
- **Month total looks low:** check the "Metric history" panel; retention may be shorter than the month.
