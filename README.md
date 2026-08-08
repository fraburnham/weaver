# Weaver

Agent tui and framework

## Components

### Phoenix.PubSub

Phoenix.PubSub is the messaging bus that connects all components. The goal is to allow the individual components to respond to each message as is appropriate.

#### `"messages"`

```elixir
%{
  role: "user" | "assistant" | "tool" | "system",
  content: String.t(),
  tool_calls: [
    %{
      id: String.t(),
      type: "function",
      function: %{name: String.t(), arguments: map()}
    } | []
  ]
}
```

#### `"commands"`

| Event | Description |
|-------|-------------|
|`:clear` | Empty and re-initalize context |

### DynamicSupervisor

`DynamicSupervisor` manages additional supervised processes when the framework is used as a TUI. It allows APIs and tools to add processes to the supervision tree.

### History

`History` writes conversation messages to JSONL (JSON Lines) files for persistence.

#### Config

```elixir
config :weaver,
  history: [base_dir: "/path/to/history/files"]
```

| Key | Description |
|-----|-------------|
| `:base_dir` | The directory where history files are stored (default: `.weaver/history/`) |

### Tools

`Tools` manages tool execution and responses and can call tools via a STDIO interface or behaviour.

#### STDIO Interface

A STDIO tool requires:
- A `definition.json` file in the tool's directory
- A `run` executable/script that accepts JSON input via STDIN
- Output to STDIO is sent to the llm verbatim
- The tool's path will be built like `<weaver.tools.base_dir>/<tool name>/`

#### Behaviour

An elixir tool must implement the `Weaver.Tool` behaviour.

#### Config

```elixir
config :weaver,
  tools: [
    base_dir: "/path/to/tools",
    tool_modules: %{"tool-name" => Elixir.Module}
  ]
```

| Key | Description |
|-----|-------------|
| `:base_dir` | The directory containing STDIO tools |
| `:tool_modules` | A map of tool names to elixir modules |

### Personas

A persona is built from a `persona.json` and a `PERSONA.md` in a directory named for the persona.

#### `persona.json`

```json
{
    "model": "model-name-or-id",
    "tools": [
        "list",
        "of",
        "tools",
        "model",
        "can",
        "use"
    ]
}
```

| Key | Description |
|-----|-------------|
| `"model"` | The name or id of the model in a format that the api client can use |
| `"tools"` | A list of tool names this persona is allowed to call |

#### `PERSONA.md`

The `PERSONA.md` file is used as the system prompt. It can be empty.

#### Config

```elixir
config :weaver,
  personas: [
    base_dir: "/path/to/persona/dirs",
    name: "name-of-the-persona-to-use"
  ]
```

| Key | Description |
|-----|-------------|
| `:base_dir` | The base directory to search for personas |
| `:name` | The name of the persona must match its dirname in the personas base dir |

### LLM

`LLM` ties together the API and message queue by:
- Maintaining conversation context with system prompt and message history
- Calling the API for each llm turn
- Broadcasting responses to all subscribers

#### Config

```elixir
config :weaver,
  llm: [api: Elixir.Module.That.Implements.Weaver.Api]
```

| Key | Description |
|-----|-------------|
| `:llm` | An elixir module that implements the `Weaver.Api` behaviour |

### TUI

`TUI` handles displaying messages to the user:
- Shows thinking content in cyan
- Displays chat responses using Marcli for markdown formatting
- Lists tool calls in yellow
- Handles prompt for user input
- Recognizes slash commands

#### Config

The `TUI` module expects:
```elixir
config :weaver,
  tui: [show_thinking: true]
```

| Key | Description |
|-----|-------------|
| `:show_thinking` | Whether to show thinking content (does not enable or disable thinking) |
