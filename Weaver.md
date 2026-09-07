# `Weaver`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/weaver.ex#L1)

# `assistant_message`

```elixir
@type assistant_message() :: %{
  optional(:resume) =&gt; boolean(),
  optional(:content) =&gt; String.t(),
  optional(:thinking) =&gt; String.t(),
  optional(:tool_calls) =&gt; [tool_call()],
  role: String.t()
}
```

# `command`

```elixir
@type command() ::
  :clear
  | :compact
  | {:resume, command()}
  | :resume_end
  | {:terminal_tool_call, any()}
```

# `message`

```elixir
@type message() :: user_message() | tool_message() | assistant_message()
```

# `metric`

```elixir
@type metric() :: %{total_tokens: non_neg_integer(), input_tokens: non_neg_integer()}
```

# `tool_call`

```elixir
@type tool_call() :: %{
  function: %{
    optional(:description) =&gt; String.t(),
    optional(:arguments) =&gt; map(),
    name: String.t()
  }
}
```

# `tool_message`

```elixir
@type tool_message() :: %{
  optional(:resume) =&gt; boolean(),
  id: integer(),
  role: String.t(),
  content: String.t()
}
```

# `user_message`

```elixir
@type user_message() :: %{
  optional(:resume) =&gt; boolean(),
  role: String.t(),
  content: String.t()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
