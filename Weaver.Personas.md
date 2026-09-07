# `Weaver.Personas`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/personas.ex#L1)

`Weaver.Personas` handles loading persona details from persona.json and PERSONA.md files.

A persona is built from a `persona.json` and a `PERSONA.md` in a directory named for the persona.

#### `persona.json`

```json
{
  "model": "model-name-or-id",
  "api": "Api.Module.Name",
  "context_window": 128000,
  "output_tokens": 16000,
  "temperature": 0.6,
  "top_p": 0.95,
  "top_k": 20,
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
| `"api"` | The elixir module to use as the api backend that implements the `Weaver.Api` behaviour |
| `"context_window"` | The maximum number of tokens the context is allowed to use |
| `"output_tokens"` | The maximum number of output tokens to generate |
| `"temperature"` | Temperature value to pass to the model |
| `"top_p"` | Top p value to pass to the model |
| `"top_k"` | Top k value to pass to the model |
| `"tools"` | A list of tool names this persona is allowed to call |

#### `PERSONA.md`

The `PERSONA.md` file is used as the system prompt. It can be empty.

#### Config

| Key | Description |
|-----|-------------|
| `:base_dir` | The base directory to search for personas |
| `:name` | The name of the persona must match its dirname in the personas base dir |

# `model_options`

```elixir
@type model_options() :: %{
  optional(:context_window) =&gt; non_neg_integer(),
  optional(:output_tokens) =&gt; non_neg_integer(),
  optional(:temperature) =&gt; float(),
  optional(:top_p) =&gt; float(),
  optional(:top_k) =&gt; non_neg_integer()
}
```

# `t`

```elixir
@type t() :: %Weaver.Personas{base_dir: String.t(), name: String.t()}
```

# `model`

```elixir
@spec model(t()) :: {String.t(), module()}
```

# `model_options`

```elixir
@spec model_options(t()) :: model_options()
```

# `system_prompt`

```elixir
@spec system_prompt(t()) :: String.t()
```

# `tools_available`

```elixir
@spec tools_available(t()) :: [String.t()]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
