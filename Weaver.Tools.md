# `Weaver.Tools`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/tools.ex#L10)

Manages tool execution and responses.

`Weaver.Tools` handles calling tools via a STDIO interface or by invoking Elixir modules
that implement the `Weaver.Tools.Tool` behaviour. It broadcasts a list of tool response
messages to the `"messages"` topic, or broadcasts to `"commands"` if a terminal tool
call is encountered.

#### STDIO Interface

A STDIO tool requires:
- A `definition.json` file in the tool's directory
- A `run` executable/script that accepts JSON input via STDIN
- Output to STDIO is sent to the llm verbatim
- The tool's path will be built like `<weaver.tools.base_dir>/<tool name>/`

#### Behaviour

An elixir tool must implement the `Weaver.Tool` behaviour.

#### Config

| Key | Description |
|-----|-------------|
| `:base_dir` | The directory containing STDIO tools |
| `:tool_modules` | A map of tool names to elixir modules |

# `definition`

```elixir
@type definition() :: %{
  type: String.t(),
  function: %{
    name: String.t(),
    description: String.t(),
    parameters: json_schema()
  }
}
```

# `json_schema`

```elixir
@type json_schema() :: map()
```

# `t`

```elixir
@type t() :: %Weaver.Tools{
  base_dir: String.t() | nil,
  tool_definitions: list() | nil,
  tool_modules: map()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_tool_definitions`

```elixir
@spec get_tool_definitions([String.t()]) :: [definition()]
```

Retrieves the definitions for the given list of tools.

Returns a list of tool definition maps. If a tool is registered as an Elixir
module, its `c:Weaver.Tools.Tool.definition/0` callback is invoked. Otherwise,
the definition is loaded from the tool's `definition.json` file via the STDIO interface.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
