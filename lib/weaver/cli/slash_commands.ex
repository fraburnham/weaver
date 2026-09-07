defmodule Weaver.CLI.SlashCommands do
  @moduledoc """
  Helpers for `Weaver.CLI` slash commands like /exit, /clear, etc.
  """

  @doc """
  Displays all the slash commands and their help strings
  """
  def help(commands) do
    IO.write("\n")

    commands
    |> Enum.map(fn {command, opts} ->
      [:bright, opts[:command] || command, :reset, ": ", opts[:help], "\n"]
    end)
    |> IO.ANSI.format()
    |> IO.write()
  end

  # [{pattern, [do: body, help: help-string, command: help-display-command]}, ...]
  defmacro generate_slash_commands(commands) do
    escaped_commands = Macro.escape(commands)

    slash_command_handlers =
      commands
      |> Enum.map(fn {pattern, data} ->
        quote do
          defp user_input(unquote(pattern)), do: unquote(data[:do])
        end
      end)

    quote do
      unquote_splicing(slash_command_handlers)

      defp user_input("/help") do
        Weaver.CLI.SlashCommands.help(unquote(escaped_commands))

        # Don't really like that this is across modules...
        prompt()
      end

      defp user_input(<<"/", command::binary>>) do
        [:bright, :red, "Unknown command: ", :reset, :bright, "/", command]
        |> IO.ANSI.format()
        |> IO.puts()

        # Don't really like that this is across modules...
        prompt()
      end
    end
  end
end
