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
  require Weaver.TUI.SlashCommands
  alias Weaver.TUI
  alias Weaver.TUI.SlashCommands

  defstruct show_thinking: false, total_tokens: nil

  @prompt_color :light_red

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %TUI{}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")
    Phoenix.PubSub.subscribe(Weaver.PubSub, "commands")
    Phoenix.PubSub.subscribe(Weaver.PubSub, "metrics")

    header()
    prompt()

    {:ok, config}
  end

  #
  # "commands" handling
  #

  @impl true
  def handle_info(:resume_end, state) do
    prompt()

    {:noreply, state}
  end

  @impl true
  def handle_info({:resume, _}, state) do
    {:noreply, state}
  end

  # Display a prompt and broadcast the user input
  @impl true
  def handle_info(:prompt, state = %TUI{total_tokens: total_tokens}) do
    (if total_tokens do
       [
         :faint,
         "\nTokens used: ",
         Integer.to_string(total_tokens),
         "\n",
         :reset
       ]
     else
       []
     end ++
       [
         @prompt_color,
         "> "
       ])
    |> IO.ANSI.format()
    |> IO.gets()
    |> String.trim()
    |> user_input()

    # TODO: handle input failure (like bad slash commands) in here so prompt triggering is private

    {:noreply, state}
  end

  @impl true
  def handle_info(:clear, state = %TUI{}) do
    {:noreply, %TUI{state | total_tokens: nil}}
  end

  # Ignore unknown commands
  @impl true
  def handle_info(command, state) when is_atom(command) do
    {:noreply, state}
  end

  #
  # "messages" handling
  #

  @impl true
  def handle_info(%{role: "user", content: content, resume: true}, config = %TUI{}) do
    [@prompt_color, "\n> ", :light_white, content]
    |> IO.ANSI.format()
    |> IO.puts()

    {:noreply, config}
  end

  @impl true
  def handle_info(msg = %{role: "assistant", resume: true}, config = %TUI{}) do
    show_thinking(config.show_thinking, msg)
    show_content(msg)
    show_tool_calls(msg)

    {:noreply, config}
  end

  # A message from the assistant without any tool calls means the assistant is ready for user input again
  @impl true
  def handle_info(msg = %{role: "assistant"}, config = %TUI{}) do
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

  #
  # "metrics" handling
  #

  @impl true
  def handle_info(%{total_tokens: total_tokens}, state = %TUI{}) do
    {:noreply, %{state | total_tokens: total_tokens}}
  end

  defp header do
    [:bright, "\nType '/exit' to quit"]
    |> IO.ANSI.format()
    |> IO.puts()
  end

  def prompt(msg) do
    if not Map.has_key?(msg, :tool_calls) do
      prompt()
    end
  end

  def prompt do
    send(__MODULE__, :prompt)
  end

  defp show_thinking(true, %{thinking: thinking}) do
    [:faint, :cyan, "\n", thinking, "\n"]
    |> IO.ANSI.format()
    |> IO.puts()
  end

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

  defp exit do
    System.stop(0)
    Process.sleep(:infinity)
  end

  defp clear do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
    # TODO: don't show here. It'll happen by message.
    prompt()
  end

  defp resume do
    IO.write("\n")

    Weaver.History.sessions()
    |> Enum.each(fn filename ->
      IO.puts(filename)
    end)

    prompt()
  end

  defp compact do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :compact)
  end

  SlashCommands.generate_slash_commands([
    {"/exit", [do: exit(), help: "Exit this session."]},
    {"/clear", [do: clear(), help: "Clear the context. This starts a new history session, too."]},
    {"/resume", [do: resume(), help: "List previous sessions that can be resumed."]},
    {<<"/resume ", session::binary>>,
     [
       do: Weaver.History.resume(session),
       help: "Resume a specific session. You can list sessions with `/resume`.",
       command: "/resume <session>"
     ]},
    {"/compact", [do: compact(), help: "Compact this session to reclaim context."]}
  ])

  # TODO: /clear-to-last-prompt

  # If the user input wasn't a slash command broadcast it
  defp user_input(content) do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{
      role: "user",
      content: content
    })
  end
end
