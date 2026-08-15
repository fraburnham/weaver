defmodule Weaver.TUI.SlashCommands do
  def help(commands) do
    IO.write("\n")
    
    commands
    |> Enum.map(fn {command, opts} ->
      [opts[:command] || command, ": ", opts[:help], "\n"]
    end)
    |> IO.write()
  end

  # [{pattern, [do: body, help: help-string]}, ...]
  defmacro generate_slash_commands(commands) do
    escaped_commands = Macro.escape(commands)
    
    slash_command_handlers = commands
    |> Enum.map(fn {pattern, data} ->
      quote do
        defp user_input(unquote(pattern)), do: unquote(data[:do])
      end
    end)
    
    quote do
      unquote_splicing(slash_command_handlers)

      defp user_input("/help") do
        Weaver.TUI.SlashCommands.help(unquote(escaped_commands))

        # Don't really like that this is across modules...
        prompt()
      end

      defp user_input(<<"/", command::binary>>) do
        [:bright, :red, "Unknown command: ", command]
        |> IO.ANSI.format()
        |> IO.puts()

        # Don't really like that this is across modules...
        prompt()
      end
    end
  end
end
