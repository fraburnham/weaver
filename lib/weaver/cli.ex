defmodule Weaver.CLI do
  @moduledoc """
  `Weaver.CLI` handles displaying messages to the user in the terminal.

  It subscribes to the `"messages"` Phoenix.PubSub topic and renders conversation
  messages with appropriate formatting. Thinking content is shown in cyan, chat
  responses are displayed using Marcli for markdown formatting, and tool calls
  are listed in yellow. The module handles user prompts and recognizes slash
  commands for quitting or other special operations.

  ## Config

  | Key | Description | Default |
  |---|---|---|
  | :show_thinking | Show thinking output from assistant messages or not | `false` |
  """

  use GenServer
  require Weaver.CLI.SlashCommands
  alias Weaver.CLI
  alias Weaver.CLI.SlashCommands
  alias Weaver.CLI.IO
  alias Weaver.CLI.ANSI

  defstruct show_thinking: false, total_tokens: nil

  @type t :: %CLI{
          show_thinking: boolean(),
          total_tokens: non_neg_integer() | nil
        }

  @prompt_color :light_red

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %CLI{}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")
    Phoenix.PubSub.subscribe(Weaver.PubSub, "commands")
    Phoenix.PubSub.subscribe(Weaver.PubSub, "metrics")

    {:ok, _} = IO.start_link(%IO{})

    header()
    prompt()

    {:ok, config}
  end

  #
  # IO messages
  #

  @impl true
  def handle_info({:keyboard_input, input}, state) do
    String.trim(input)
    |> user_input

    {:noreply, state}
  end

  #
  # "commands" handling
  #

  # Terminal tools don't make sense to me when the CLI is in use
  @impl true
  def handle_info({:termminal_tool_call, _}, _),
    do: raise("Terminal tool called while using CLI!")

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
  def handle_info(:prompt, state = %CLI{total_tokens: total_tokens}) do
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
    |> ANSI.format()
    |> IO.prompt()

    # To make life _fun_ the prompt is async. Weaver.CLI.IO handles it and output so that things stay in
    # sync with a little less fuss. A {:keyboard_input, input} message will come when the user presses enter

    {:noreply, state}
  end

  @impl true
  def handle_info(:clear, state = %CLI{}) do
    {:noreply, %CLI{state | total_tokens: nil}}
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
  @spec handle_info(Weaver.message(), t()) :: {:noreply, t()}
  def handle_info(%{role: "user", content: content, resume: true}, config = %CLI{}) do
    [@prompt_color, "\n> ", :light_white, content]
    |> ANSI.format()
    |> IO.puts()

    {:noreply, config}
  end

  @impl true
  @spec handle_info(Weaver.message(), t()) :: {:noreply, t()}
  def handle_info(msg = %{role: "assistant", resume: true}, config = %CLI{}) do
    show_thinking(config.show_thinking, msg)
    show_content(msg)
    show_tool_calls(msg)

    {:noreply, config}
  end

  # A message from the assistant without any tool calls means the assistant is ready for user input again
  @impl true
  @spec handle_info(Weaver.message(), t()) :: {:noreply, t()}
  def handle_info(msg = %{role: "assistant"}, config = %CLI{}) do
    show_thinking(config.show_thinking, msg)
    show_content(msg)
    show_tool_calls(msg)
    prompt(msg)

    {:noreply, config}
  end

  @impl true
  @spec handle_info(Weaver.message(), t()) :: {:noreply, t()}
  def handle_info(%{role: _}, state = %CLI{}) do
    {:noreply, state}
  end

  # A list of messages is always tool call responses. Don't need to show that in the UI.
  @impl true
  @spec handle_info(list(Weaver.message()), t()) :: {:noreply, t()}
  def handle_info([%{role: _} | _], state = %CLI{}) do
    {:noreply, state}
  end

  #
  # "metrics" handling
  #

  @impl true
  def handle_info(%{total_tokens: total_tokens}, state = %CLI{}) do
    {:noreply, %{state | total_tokens: total_tokens}}
  end

  #
  # private
  #

  @spec header :: :ok
  defp header do
    [:bright, "\nType '/exit' to quit"]
    |> ANSI.format()
    |> IO.puts()
  end

  @spec prompt(Weaver.message()) :: :ok | nil
  defp prompt(msg) do
    if not Map.has_key?(msg, :tool_calls) do
      prompt()
    end
  end

  @spec prompt :: :ok
  defp prompt do
    send(__MODULE__, :prompt)
  end

  @spec show_thinking(boolean(), Weaver.message()) :: :ok | nil
  defp show_thinking(true, %{thinking: thinking}) do
    [:faint, :cyan, "\n", thinking, "\n"]
    |> ANSI.format()
    |> IO.puts()
  end

  defp show_thinking(_, _), do: nil

  @spec show_content(Weaver.message()) :: :ok | nil
  defp show_content(%{content: ""}), do: nil

  defp show_content(%{content: content}) when not is_nil(content) do
    Marcli.render(content)
    |> IO.puts()
  end

  defp show_content(_), do: nil

  @spec show_tool_calls(Weaver.message()) :: :ok
  defp show_tool_calls(%{tool_calls: tool_calls}) do
    [:yellow, "\n", Enum.map(tool_calls, fn call -> "- #{call[:function][:name]}\n" end)]
    |> ANSI.format()
    |> IO.puts()
  end

  @spec show_tool_calls(Weaver.message()) :: :ok
  defp show_tool_calls(_), do: :ok

  @spec exit :: no_return()
  defp exit do
    System.stop(0)
    Process.sleep(:infinity)
  end

  @spec clear :: :ok
  defp clear do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)

    prompt()
  end

  @spec resume :: :ok
  defp resume do
    Elixir.IO.write("\n")

    Weaver.History.sessions()
    |> Enum.each(fn filename ->
      IO.puts(filename)
    end)

    prompt()
  end

  @spec compact :: :ok
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

  # If the user input wasn't a slash command broadcast it
  @spec user_input(String.t()) :: :ok
  defp user_input(content) do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{
      role: "user",
      content: content
    })
  end
end
