# Weaver

Agent framework and cli.

## CLI

Run `./weaver` after setting the config options to use `weaver` as an interactive cli tool.

### Config

Api modules may require additional configuration.

| ENV Var | Description | Default |
|---|---|---|
| `WEAVER_PERSONA` | The [persona](#personas) to use with `weaver`. | |
| `WEAVER_PERSONAS_BASE_DIR` | The directory that has personas. | |
| `WEAVER_TOOLS_BASE_DIR` | The directory that has `STDIO` [tools](#tools). | |
| `WEAVER_HISTORY_BASE_DIR` | The directory for `Weaver.History` to output jsonl files. | `.weaver/history` |
| `WEAVER_SHOW_THINKING` | Show thinking output in the TUI or not. | `"yes"` |

## Framework

As a framework `weaver`'s goal is to be very flexible. To achieve that all core communication happens over `Phoenix.PubSub` so that process can choose what to consume and how to deal with the messages.

### `Phoenix.PubSub`

There are three topics that a process can subscribe to: 

* `"messages"`
  * Where each message in the agent's conversation is broadcast.
* `"commands"`
  * Where commands (like `:clear` and `:compact`) are broadcast.
* `"metrics"`
  * Where token usage metrics are broadcast.
  
The types for each are on `Weaver`.

### Processes

The processes that `weaver` starts can be configured like

```elixir
config :weaver,
  processes: [
    DynamicSupervisor,
    Phoenix.PubSub,
    Weaver.History,
    Weaver.Tools,
    Weaver.LLM,
    Weaver.CLI
  ]
```

Omitting a process from this list will prevent it from starting so that you can start another process instead (or none at all). See `config/test.exs` for an example. See `Weaver.Application` for a complete list of processes.

## Tools

Tools can be implemented against the `STDIO` interface or as Elixir modules. Some `STDIO` tools can be found in `tools/`. See `Weaver.Tools` for more details.

## Personas

A persona is a directory with `PERSONA.md` and `persona.json` files that describe it. Some default personas can be found in `personas/`. See `Weaver.Personas` for more details.

```text
${WEAVER_PERSONAS_BASE_DIR}/
├── <persona-name>
│   ├── persona.json
│   ├── PERSONA.md
└── <persona-name>
    ├── persona.json
    └── PERSONA.md
```
