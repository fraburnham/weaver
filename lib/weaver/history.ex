defmodule Weaver.History do
  @moduledoc """
  `Weaver.History` persists conversation messages to JSONL files.

  It subscribes to the `"messages"` Phoenix.PubSub topic and captures all messages,
  encoding each as JSON and appending to a timestamped file. Each new conversation automatically
  creates a new file with an ISO 8601 timestamp. When the server terminates (on shutdown or
  error), the file descriptor is properly closed.
  """

  use GenServer

  alias Weaver.History

  defstruct base_dir: nil

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(%History{base_dir: base_dir}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")
    Phoenix.PubSub.subscribe(Weaver.PubSub, "commands")

    {:ok, {nil, base_dir}}
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
  def handle_info(:clear, {_, base_dir}) do
    {:ok, file_descriptor} = init_history_file(base_dir)
    {:noreply, {file_descriptor, base_dir}}
  end

  @impl true
  def handle_info(command, state = {file_descriptor, _})
      when is_atom(command) and not is_nil(file_descriptor) do
    update_file(file_descriptor, %{command: command})

    {:noreply, state}
  end

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
  def handle_call(:sessions, _, state = {_, base_dir}) do
    {:ok, files} = File.ls(base_dir)

    {:reply, files, state}
  end

  #
  # public api handlers
  #

  @impl true
  def handle_cast({:start_resume, history_file}, {_, base_dir}) do
    [base_dir, history_file]
    |> Path.join()
    |> Path.expand()
    |> File.stream!(:line, encoding: :utf8)
    |> Enum.each(fn line ->
      resume_line(
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

  defp resume_line(msg = %{role: _}) do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", msg)
  end

  defp resume_line(%{command: cmd}) do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", {:resume, String.to_atom(cmd)})
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

  def resume(history_file) do
    GenServer.cast(__MODULE__, {:start_resume, history_file})
  end

  def sessions do
    GenServer.call(__MODULE__, :sessions)
    |> Enum.filter(fn el -> String.ends_with?(el, ".jsonl") end)
    |> Enum.sort()
  end
end
