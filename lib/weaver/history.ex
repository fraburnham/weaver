defmodule Weaver.History do
  @moduledoc """
  Persists conversation messages to JSONL files.

  Subscribes to the `"messages"` and `"commands"` Phoenix.PubSub topics,
  encoding each message/command as JSON and appending to timestamped files.
  Each new conversation or resume creates a new file with an ISO 8601 timestamp.
  The file descriptor is properly closed when the server terminates.

  ## History Resumption

  Use `resume/1` to replay messages from a previous session file. This broadcasts
  all messages back to the `"messages"` topic and commands to the `"commands"` topic,
  allowing other components to reconstruct their state.

  ## Examples

      iex> Weaver.History.resume("2025-01-15T10:30:00.000000Z.jsonl")
      :ok

      iex> Weaver.History.sessions()
      ["2025-01-14T09:00:00.000000Z.jsonl", "2025-01-15T10:30:00.000000Z.jsonl"]

  """

  use GenServer

  alias Weaver.History

  defstruct base_dir: nil,
            pubsub: nil

  def start_link(options) do
    config =
      struct!(History, [{:pubsub, Application.get_env(:weaver, :pubsub)} | options[:config]])

    GenServer.start_link(__MODULE__, config, name: options[:name] || __MODULE__)
  end

  @impl true
  def init(config = %History{base_dir: _, pubsub: pubsub}) do
    Phoenix.PubSub.subscribe(pubsub, "messages")
    Phoenix.PubSub.subscribe(pubsub, "commands")

    {:ok, {nil, config}}
  end

  @impl true
  def terminate(_reason, {file_descriptor, _}) do
    File.close(file_descriptor)
  end

  #
  # "commands" handlers
  #

  @impl true
  def handle_info(:resume_end, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:resume, _}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:clear, {_, config = %History{base_dir: base_dir}}) do
    {:ok, file_descriptor} = init_history_file(base_dir)
    {:noreply, {file_descriptor, config}}
  end

  @impl true
  def handle_info(command, state = {file_descriptor, _})
      when is_atom(command) and not is_nil(file_descriptor) do
    update_file(file_descriptor, %{command: command})

    {:noreply, state}
  end

  # Terminal tool calls can be ignored by the history worker because they'll already be written as assistant messages
  @impl true
  def handle_info({:termminal_tool_call, _}, state), do: {:noreply, state}

  #
  # "messages" handlers
  #

  @impl true
  def handle_info(%{resume: true}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = %{role: _role}, state = {file_descriptor, _})
      when not is_nil(file_descriptor) do
    update_file(file_descriptor, msg)

    {:noreply, state}
  end

  @impl true
  def handle_info(msgs = [%{role: _} | _], state = {file_descriptor, _})
      when not is_nil(file_descriptor) do
    for msg <- msgs, do: update_file(file_descriptor, msg)

    {:noreply, state}
  end

  @impl true
  def handle_call(:sessions, _, state = {_, %History{base_dir: base_dir}}) do
    {:ok, files} = File.ls(base_dir)

    {:reply, files, state}
  end

  #
  # public api handlers
  #

  @impl true
  def handle_cast(
        {:start_resume, history_file},
        {_, %History{base_dir: base_dir, pubsub: pubsub}}
      ) do
    [base_dir, history_file]
    |> Path.join()
    |> Path.expand()
    |> File.stream!(:line, encoding: :utf8)
    |> Enum.each(fn line ->
      resume_line(
        pubsub,
        Jason.decode!(line, keys: :atoms)
        |> Map.put(:resume, true)
      )
    end)

    # The resume_end signals that normal interaction can resume
    Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :resume_end)

    {:ok, file_descriptor} = init_history_file(base_dir)
    {:noreply, {file_descriptor, base_dir}}
  end

  #
  # private helpers
  #

  defp update_file(file_descriptor, msg) do
    IO.puts(file_descriptor, Jason.encode_to_iodata!(msg))
  end

  defp resume_line(pubsub, msg = %{role: _}) do
    Phoenix.PubSub.broadcast(pubsub, "messages", msg)
  end

  defp resume_line(pubsub, %{command: cmd}) do
    Phoenix.PubSub.broadcast(pubsub, "commands", {:resume, String.to_atom(cmd)})
  end

  defp init_history_file(base_dir) do
    history_file_path =
      [base_dir, "#{DateTime.to_iso8601(DateTime.utc_now())}.jsonl"]
      |> Path.join()
      |> Path.expand()

    File.mkdir_p!(base_dir |> Path.expand())
    File.open(history_file_path, [:append, :utf8])
  end

  #
  # public api
  #

  @doc """
  Resumes a previous conversation by replaying messages from the given history file.

  Broadcasts all messages to the `"messages"` topic and commands to the `"commands"` topic
  with a `resume: true` flag. After completion, broadcasts `:resume_end` and initializes
  a new history file for the resumed conversation.

  ## Examples

      iex> Weaver.History.resume("2025-01-15T10:30:00.000000Z.jsonl")
      :ok

  """
  def resume(history_file) do
    resume(history_file, __MODULE__)
  end

  @doc """
  Resumes a previous conversation by replaying messages from the given history file
  on the specified process.

  ## Examples

      iex> Weaver.History.resume("2025-01-15T10:30:00.000000Z.jsonl", pid)
      :ok

  """
  def resume(history_file, pid) do
    GenServer.cast(pid, {:start_resume, history_file})
  end

  @doc """
  Lists all available history sessions (JSONL files).

  Returns a sorted list of history file names.

  ## Examples

      iex> Weaver.History.sessions()
      ["2025-01-14T09:00:00.000000Z.jsonl", "2025-01-15T10:30:00.000000Z.jsonl"]

  """
  def sessions do
    sessions(__MODULE__)
  end

  @doc """
  Lists all available history sessions (JSONL files) from the specified process.

  ## Examples

      iex> Weaver.History.sessions(pid)
      ["2025-01-14T09:00:00.000000Z.jsonl", "2025-01-15T10:30:00.000000Z.jsonl"]

  """
  def sessions(pid) do
    GenServer.call(pid, :sessions)
    |> Enum.filter(fn el -> String.ends_with?(el, ".jsonl") end)
    |> Enum.sort()
  end
end
