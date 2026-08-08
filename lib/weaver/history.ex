@moduledoc """
@doc ~S"""
`Weaver.History` is a GenServer that persists conversation messages to JSONL files.

It subscribes to the `"messages"` Phoenix.PubSub topic and captures all messages,
encoding each as JSON and appending to a timestamped file. This provides an
out-of-the-box way to persist conversation history for later review or analysis.

Each new conversation automatically creates a new file with an ISO 8601 timestamp.
When the server terminates (on shutdown or error), the file descriptor is properly closed.

### Message Format

Messages are stored in JSONL (JSON Lines) format, with one JSON object per line.

Each message has:
  - `role`: `"user"`, `"assistant"`, `"tool"`, or `"system"`
  - `content`: the message content as a string
  - `tool_calls`: an optional list of tool calls made in this message

### Config

```elixir
{History, struct!(History, Application.get_env(:weaver, :history))}
```

Where `:history` is a map with:
  - `:base_dir` - The directory where history files are stored (default: `~/.weaver`)
"""

defmodule Weaver.History do
  use GenServer

  alias Weaver.History

  defstruct base_dir: nil

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(%History{base_dir: base_dir}) do
    history_file_path =
      [base_dir, "#{DateTime.to_iso8601(DateTime.utc_now())}.jsonl"]
      |> Path.join()
      |> Path.expand()

    File.mkdir_p!(base_dir |> Path.expand())
    {:ok, file_descriptor} = File.open(history_file_path, [:append, :utf8])

    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, file_descriptor}
  end

  @impl true
  def handle_info(msg = %{role: _role}, file_descriptor) do
    update_file(file_descriptor, msg)

    {:noreply, file_descriptor}
  end

  @impl true
  def handle_info(msgs = [%{role: _} | _], file_descriptor) do
    for msg <- msgs, do: update_file(file_descriptor, msg)

    {:noreply, file_descriptor}
  end

  @impl true
  def terminate(_reason, file_descriptor) do
    File.close(file_descriptor)
  end

  defp update_file(file_descriptor, msg) do
    IO.puts(file_descriptor, Jason.encode_to_iodata!(msg))
  end
end