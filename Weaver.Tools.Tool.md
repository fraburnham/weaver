# `Weaver.Tools.Tool`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/tools.ex#L1)

A behaviour for implementing tools as elixir modules

# `definition`

```elixir
@callback definition() :: Weaver.Tools.definition()
```

# `run`

```elixir
@callback run(tool_call :: Weaver.tool_call()) :: binary()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
