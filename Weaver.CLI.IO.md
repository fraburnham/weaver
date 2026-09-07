# `Weaver.CLI.IO`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/cli/io.ex#L1)

Allows the user prompt to be handled async. Relies on `Weaver.CLI.Term` for configuring the terminal.

The standard `IO` moudle should not be used when using `Weaver.CLI.IO`. In order for this module to
keep the prompt at the bottom of the display no other process can write to stdout.

# `t`

```elixir
@type t() :: %Weaver.CLI.IO{
  buffer: [char()],
  caller: reference() | nil,
  original_term_config: map() | nil,
  prompt: IO.chardata() | nil,
  prompt_state: :not_prompting | :prompting
}
```

# `term_config`

```elixir
@type term_config() :: map()
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `prompt`

```elixir
@spec prompt(IO.chardata()) :: :ok | {:error, :prompting}
```

Display a prompt collecting keyboard input until enter is pressed.

Once the user presses enter a message will be sent to the caller like
```elixir
{:keyboard_input, String.t()}
```
and polling will be stopped.

# `puts`

```elixir
@spec puts(IO.chardata()) :: :ok
```

Write to stdout like IO.puts/2.

This will interrupt any prompt (if it is collecting input) so that output can be displayed
then the prompt will be displayed again after the output.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
