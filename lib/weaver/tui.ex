defmodule Weaver.TUI do
  @moduledoc """
  `Weaver.TUI` handles displaying messages to the user in the terminal.

  It subscribes to the `"messages"` Phoenix.PubSub topic and renders conversation
  messages with appropriate formatting. Thinking content is shown in cyan, chat
  responses are displayed using Marcli for markdown formatting, and tool calls
  are listed in yellow. The module handles user prompts and recognizes slash
  commands for quitting or other special operations.
  """

  use GenServer
  alias Weaver.TUI

  defstruct show_thinking: false

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %TUI{}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    header()
    prompt()

    {:ok, config}
  end

  # A message from the assistant without any tool calls means the assistant is ready for user input again
  @impl true
  def handle_info(msg = %{role: "assistant"}, config = %TUI{}) do
    # TODO: a message module so that I can define a message struct? probably will help with consistency later
    show_thinking(config.show_thinking, msg)
    show_content(msg)
    show_tool_calls(msg)
    prompt(msg)

    {:noreply, config}
  end

  @impl true
  def handle_info(%{role: _}, state = %TUI{}) do
    {:noreply, state}
  end

  # A list of messages is always tool call responses. Don't need to show that in the UI.
  @impl true
  def handle_info([%{role: _} | _], state = %TUI{}) do
    {:noreply, state}
  end

  # Display a prompt and broadcast the user input
  @impl true
  def handle_info(:prompt, state = %TUI{}) do
    [:red, "\n> "]
    |> IO.ANSI.format()
    |> IO.gets()
    |> String.trim()
    |> user_input()

    {:noreply, state}
  end

  defp header do
    [:bright, "\nType '/exit' to quit"]
    |> IO.ANSI.format()
    |> IO.puts()
  end

  defp prompt(msg) do
    if not Map.has_key?(msg, :tool_calls) do
      prompt()
    end
  end

  defp prompt do
    send(__MODULE__, :prompt)
  end

  defp show_thinking(true, %{thinking: thinking}),
    do: [:faint, :cyan, "\n", thinking, "\n"] |> IO.ANSI.format() |> IO.puts()

  defp show_thinking(_, _), do: nil

  defp show_content(%{content: ""}), do: nil

  defp show_content(%{content: content}) when not is_nil(content) do
    Marcli.render(content)
    |> IO.puts()
  end

  defp show_content(_), do: nil

  defp show_tool_calls(%{tool_calls: tool_calls}) do
    [:yellow, "\n", Enum.map(tool_calls, fn call -> "- #{call[:function][:name]}\n" end)]
    |> IO.ANSI.format()
    |> IO.puts()
  end

  defp show_tool_calls(_), do: nil

  defp user_input("/exit") do
    System.stop(0)
    Process.sleep(:infinity)
  end

  defp user_input(<<"/", command::binary>>) do
    [:bright, :red, "Unknown command: ", command]
    |> IO.ANSI.format()
    |> IO.puts()

    prompt()
  end

  # If the user input wasn't a slash command broadcast it
  defp user_input(content) do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{
      role: "user",
      content: content
    })
  end
end
