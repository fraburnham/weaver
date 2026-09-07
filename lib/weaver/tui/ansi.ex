defmodule Weaver.TUI.ANSI.Macros do
  @moduledoc """
  Helpers to reduce boilerplate for handling ANSI control sequences
  """

  defmacro build_commands(commands) do
    Enum.map(commands, fn
      {command_name, {fmt, default}} ->
        quote do
          @spec unquote(command_name)() :: binary()
          def unquote(command_name)(), do: unquote(command_name)(unquote(default))
          @spec unquote(command_name)(number() | tuple()) :: binary()
          def unquote(command_name)(unquote(Macro.var(:args, nil))), do: unquote(fmt)
        end

      {command_name, fmt} ->
        quote do
          @spec unquote(command_name)() :: binary()
          def unquote(command_name)(), do: unquote(fmt)
        end
    end)
  end
end

defmodule Weaver.TUI.ANSI do
  @moduledoc """
  ANSI control sequences not provided by IO.ANSI

  ## References

  https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
  https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
  """

  import Weaver.TUI.ANSI.Macros

  build_commands(
    insert_blank: {"\e[#{args}@", 1},
    shift_left: {"\e[#{args} @", 1},
    shift_right: {"\e[#{args} A", 1},
    cursor_up: {"\e[#{args}A", 1},
    cursor_down: {"\e[#{args}B", 1},
    cursor_forward: {"\e[#{args}C", 1},
    cursor_backward: {"\e[#{args}D", 1},
    cursor_next_line: {"\e[#{args}E", 1},
    cursor_preceding_line: {"\e[#{args}F", 1},
    cursor_column: {"\e[#{args}G", 1},
    cursor_position:
      {"\e[#{Tuple.to_list(args) |> Enum.at(0)};#{Tuple.to_list(args) |> Enum.at(1)}H", {1, 1}},
    display_erase_below: "\e[0J",
    display_erase_above: "\e[1J",
    display_erase_all: "\e[2J",
    line_erase_right: "\e[0K",
    line_erase_left: "\e[1K",
    line_erase_all: "\e[2K",
    insert_lines: {"\e[#{args}L", 1},
    delete_lines: {"\e[#{args}M", 1},
    delete_characters: {"\e[#{args}P", 1}
  )

  @doc """
  Use `format/1` like [`IO.ANSI.format/2`](https://elixir.hexdocs.pm/1.20.4/IO.ANSI.html#format/2). Calls
  IO.ANSI so all escapes supported there can be used here.

  ```elixir
  [:display_erase_all, {:cursor_position, {10, 10}}, :red, "Hello world!"]
  |> Weaver.TUI.ANSI.format()
  |> IO.puts()
  ```
  """
  @spec format(list()) :: IO.chardata()
  def format(commands) when is_list(commands) do
    Enum.map(commands, &format(&1))
    |> IO.ANSI.format()
  end

  @spec format(atom()) :: IO.chardata() | atom()
  def format(command) when is_atom(command) do
    if function_exported?(__MODULE__, command, 0) do
      apply(__MODULE__, command, [])
    else
      command
    end
  end

  @spec format({atom(), any()}) :: IO.chardata() | atom()
  def format({command, args}) when is_atom(command) do
    if function_exported?(__MODULE__, command, 1) do
      apply(__MODULE__, command, [args])
    else
      command
    end
  end

  @spec format(any()) :: any()
  def format(passthrough), do: passthrough
end
