# Weaver

Agent tui and framework

## Components

### Phoenix.PubSub

Phoenix.PubSub is the messaging bus that connects all components. It broadcasts and subscribes to the `"messages"` topic, allowing:
- User input from TUI to flow to the LLM
- Tool responses from Tools to flow to the LLM
- LLM responses to flow to all subscribers (TUI, History)
- System prompts to initialize the conversation context

#### `"messages"`

Messages have this shape:
```elixir
%{
  role: "user" | "assistant" | "tool" | "system",
  content: String.t(),
  tool_calls: [
    %{
      id: String.t(),
      type: "function",
      function: %{name: String.t(), arguments: String.t()}
    } | []
  ]
}
```

### DynamicSupervisor

`DynamicSupervisor` manages additional supervised processes when the framework is used as a TUI. It handles APIs and other services that need to be supervised dynamically.

### History

`History` is a GenServer that writes conversation messages to JSONL (JSON Lines) files for persistence. It subscribes to the `"messages"` PubSub topic and captures all messages. Each message is encoded as JSON and appended to a timestamped file.

When the `History` server terminates, it closes the file descriptor. New conversations automatically create new files with ISO 8601 timestamps.

#### Config

The `History` module expects the following configuration in `mix.exs`:

```elixir
{History, struct!(History, Application.get_env(:weaver, :history))}
```

The `:history` config is a map with:
- `:base_dir` - The directory where history files are stored (default: `~/.weaver`)

Example:
```elixir
config :weaver, history: %{base_dir: Path.expand("~/.weaver")}
```

Example file path:
```
~/.weaver/2024-07-28T17-40-00Z.jsonl
```

### Tools

`Tools` manages tool execution and responses. It subscribes to `"messages"` and when an assistant message with tool calls arrives, it executes the tools and broadcasts the responses.

#### STDIO Interface

Tools can be external programs. The interface expects:
- A `definition.json` file in the tool's directory
- A `run` executable/script that accepts JSON input via STDIN
- Output is captured from STDIO

#### Behaviour

Tools implement this behavior:
```elixir
defmodule MyApp.Tool do
  @callback run(tool_call :: map) :: binary
  @callback definition() :: map
end
```

#### Config

The `Tools` module expects:
```elixir
{Tools, struct!(Tools, Application.get_env(:weaver, :tools))}
```

The `:tools` config is a map with:
- `:base_dir` - The directory containing tool executables
- `:tool_modules` - A map of module names to tool structs

### LLM

`LLM` is a GenServer that orchestrates the conversation loop. It ties together the API and message queue by:
1. Maintaining conversation context with system prompt and message history
2. Processing user messages and tool responses
3. Calling the API for each turn
4. Broadcasting responses to all subscribers

It broadcasts the system prompt on init and handles both user/tool messages and tool response lists.

#### Config

The `LLM` module expects:
```elixir
{LLM, struct!(LLM, [
  {:model, model},
  {:system_prompt, system_prompt},
  {:tools_available, tools_available}
| Application.get_env(:weaver, :llm)
])}
```

### TUI

The `TUI` listens for messages from the PubSub bus and displays them with different formatting:
- Shows thinking content in cyan
- Displays content using Marcli for markdown formatting
- Lists tool calls in yellow
- Handles prompts for user input
- Recognizes `/exit` command to quit

#### Config

The `TUI` module expects:
```elixir
{TUI, struct!(TUI, Application.get_env(:weaver, :tui))}
```

The `:tui` config is a map with:
- `:show_thinking` - Whether to show thinking content

## Tui vs Framework

As a **TUI**, you interact directly with the interface. As a **framework**, you build applications that use the underlying infrastructure. Think about which use case you need for extensibility.
