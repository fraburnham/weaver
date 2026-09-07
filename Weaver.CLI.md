# `Weaver.CLI`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/cli.ex#L1)

`Weaver.CLI` handles displaying messages to the user in the terminal.

It subscribes to the `"messages"` Phoenix.PubSub topic and renders conversation
messages with appropriate formatting. Thinking content is shown in cyan, chat
responses are displayed using Marcli for markdown formatting, and tool calls
are listed in yellow. The module handles user prompts and recognizes slash
commands for quitting or other special operations.

# `t`

```elixir
@type t() :: %Weaver.CLI{
  show_thinking: boolean(),
  total_tokens: non_neg_integer() | nil
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
