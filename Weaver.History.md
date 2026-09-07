# `Weaver.History`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/history.ex#L1)

Persists conversation messages to JSONL files.

Subscribes to the `"messages"` and `"commands"` Phoenix.PubSub topics,
encoding each message/command as JSON and appending to timestamped files.
Each new conversation or resume creates a new file with an ISO 8601 timestamp.
The file descriptor is properly closed when the server terminates.

## Config

| Key | Description |
|-----|-------------|
| `:base_dir` | The directory where history files are stored (default: `.weaver/history/`) |

## History Resumption

Use `resume/1` to replay messages from a previous session file. This broadcasts
all messages back to the `"messages"` topic and commands to the `"commands"` topic,
allowing other components to reconstruct their state.

# `config`

```elixir
@type config() :: %Weaver.History{base_dir: term(), pubsub: term()}
```

# `file_descriptor`

```elixir
@type file_descriptor() :: File.io_device()
```

# `formatted_command`

```elixir
@type formatted_command() :: %{command: Weaver.command()}
```

# `pubsub_name`

```elixir
@type pubsub_name() :: atom()
```

# `state`

```elixir
@type state() :: {file_descriptor() | nil, config()}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `resume`

```elixir
@spec resume(String.t()) :: :ok
```

Resumes a previous conversation by replaying messages from the given history file.

Broadcasts all messages to the `"messages"` topic and commands to the `"commands"` topic
with a `resume: true` flag. After completion, broadcasts `:resume_end` and initializes
a new history file for the resumed conversation.

# `resume`

```elixir
@spec resume(String.t(), GenServer.server()) :: :ok
```

Resumes a previous conversation by replaying messages from the given history file
on the specified process.

# `sessions`

```elixir
@spec sessions() :: [String.t()]
```

Lists all available history sessions (JSONL files).

Returns a sorted list of history file names.

# `sessions`

```elixir
@spec sessions(GenServer.server()) :: [String.t()]
```

Lists all available history sessions (JSONL files) from the specified process.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
