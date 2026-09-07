# `Weaver.LLM`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/llm.ex#L1)

Maintains conversation context and manages LLM interactions.

`Weaver.LLM` ties together the API and messages topic by:
- Maintaining conversation context with system prompt and message history
- Calling the API for each LLM turn
- Broadcasting responses to all subscribers

## Configuration

    config :weaver,
      llm: [api: Elixir.Module.That.Implements.Weaver.Api]

| Key | Description |
|-----|------|
| `:api` | An elixir module that implements the `Weaver.Api` behaviour |

# `context`

```elixir
@type context() :: %{
  optional(:options) =&gt; Weaver.Personas.model_options(),
  optional(:messages) =&gt; [Weaver.message()],
  optional(:tools) =&gt; [Weaver.Tools.definition()] | nil,
  model: String.t()
}
```

# `t`

```elixir
@type t() :: %Weaver.LLM{
  api: module(),
  api_pid: pid() | nil,
  context: context() | nil,
  model: String.t(),
  model_options: Weaver.Personas.model_options(),
  skip_init: boolean(),
  system_prompt: String.t() | nil,
  tools_available: list() | nil,
  total_tokens: integer() | nil
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
