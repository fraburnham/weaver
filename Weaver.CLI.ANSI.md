# `Weaver.CLI.ANSI`
[🔗](https://github.com/fraburnham/weaver/blob/main/lib/weaver/cli/ansi.ex#L25)

ANSI control sequences not provided by IO.ANSI

## References

https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797

# `cursor_backward`

```elixir
@spec cursor_backward() :: binary()
```

# `cursor_backward`

```elixir
@spec cursor_backward(number() | tuple()) :: binary()
```

# `cursor_column`

```elixir
@spec cursor_column() :: binary()
```

# `cursor_column`

```elixir
@spec cursor_column(number() | tuple()) :: binary()
```

# `cursor_down`

```elixir
@spec cursor_down() :: binary()
```

# `cursor_down`

```elixir
@spec cursor_down(number() | tuple()) :: binary()
```

# `cursor_forward`

```elixir
@spec cursor_forward() :: binary()
```

# `cursor_forward`

```elixir
@spec cursor_forward(number() | tuple()) :: binary()
```

# `cursor_next_line`

```elixir
@spec cursor_next_line() :: binary()
```

# `cursor_next_line`

```elixir
@spec cursor_next_line(number() | tuple()) :: binary()
```

# `cursor_position`

```elixir
@spec cursor_position() :: binary()
```

# `cursor_position`

```elixir
@spec cursor_position(number() | tuple()) :: binary()
```

# `cursor_preceding_line`

```elixir
@spec cursor_preceding_line() :: binary()
```

# `cursor_preceding_line`

```elixir
@spec cursor_preceding_line(number() | tuple()) :: binary()
```

# `cursor_up`

```elixir
@spec cursor_up() :: binary()
```

# `cursor_up`

```elixir
@spec cursor_up(number() | tuple()) :: binary()
```

# `delete_characters`

```elixir
@spec delete_characters() :: binary()
```

# `delete_characters`

```elixir
@spec delete_characters(number() | tuple()) :: binary()
```

# `delete_lines`

```elixir
@spec delete_lines() :: binary()
```

# `delete_lines`

```elixir
@spec delete_lines(number() | tuple()) :: binary()
```

# `display_erase_above`

```elixir
@spec display_erase_above() :: binary()
```

# `display_erase_all`

```elixir
@spec display_erase_all() :: binary()
```

# `display_erase_below`

```elixir
@spec display_erase_below() :: binary()
```

# `format`

```elixir
@spec format(list()) :: IO.chardata()
@spec format(atom()) :: IO.chardata() | atom()
@spec format({atom(), any()}) :: IO.chardata() | atom()
@spec format(any()) :: any()
```

Use `format/1` like [`IO.ANSI.format/2`](https://elixir.hexdocs.pm/1.20.4/IO.ANSI.html#format/2). Calls
IO.ANSI so all escapes supported there can be used here.

```elixir
[:display_erase_all, {:cursor_position, {10, 10}}, :red, "Hello world!"]
|> Weaver.CLI.ANSI.format()
|> IO.puts()
```

# `insert_blank`

```elixir
@spec insert_blank() :: binary()
```

# `insert_blank`

```elixir
@spec insert_blank(number() | tuple()) :: binary()
```

# `insert_lines`

```elixir
@spec insert_lines() :: binary()
```

# `insert_lines`

```elixir
@spec insert_lines(number() | tuple()) :: binary()
```

# `line_erase_all`

```elixir
@spec line_erase_all() :: binary()
```

# `line_erase_left`

```elixir
@spec line_erase_left() :: binary()
```

# `line_erase_right`

```elixir
@spec line_erase_right() :: binary()
```

# `shift_left`

```elixir
@spec shift_left() :: binary()
```

# `shift_left`

```elixir
@spec shift_left(number() | tuple()) :: binary()
```

# `shift_right`

```elixir
@spec shift_right() :: binary()
```

# `shift_right`

```elixir
@spec shift_right(number() | tuple()) :: binary()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
