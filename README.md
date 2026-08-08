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

### DynamicSupervisor

`DynamicSupervisor` manages additional supervised processes when the framework is used as a TUI. It allows APIs and tools to add processes to the supervision tree.

### History

`History` writes conversation messages to JSONL (JSON Lines) files for persistence.

#### Config

```elixir
config :weaver,
  history: [base_dir: "/path/to/history/files"]
```

- `:base_dir` - The directory where history files are stored (default: `.weaver/history/`)

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

- `:base_dir` - The directory containing STDIO tools
- `:tool_modules` - A map of tool names to elixir modules

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

- `:llm` - An elixir module that implements the `Weaver.Api` behaviour

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

- `:show_thinking` - Whether to show thinking content (does not enable or disable thinking)
