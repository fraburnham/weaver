# `Weaver.Api`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/api.ex#L1)

`Weaver.Api` is a behaviour that describes an api `Weaver.LLM` can use

# `response`

```elixir
@type response() :: %{
  message: Weaver.message(),
  input_tokens: non_neg_integer(),
  total_tokens: non_neg_integer()
}
```

# `chat`

```elixir
@callback chat(context :: Weaver.LLM.context()) :: response()
```

# `start_link`

```elixir
@callback start_link() :: GenServer.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
