defmodule Weaver.History do
  use GenServer

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(_) do
    # TODO: history path from config
    history_file_path = ".weaver/history/" <> DateTime.to_iso8601(DateTime.utc_now()) <> ".jsonl"

    :ok = File.mkdir_p(".weaver/history/")
    {:ok, file_descriptor} = File.open(history_file_path, [:append])

    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, file_descriptor}
  end

  @impl true
  def handle_info(msg = %{role: _role}, file_descriptor) do
    IO.write(file_descriptor, JSON.encode_to_iodata!(msg))
    IO.write(file_descriptor, "\n")

    {:noreply, file_descriptor}
  end

  @impl true
  def terminate(_reason, file_descriptor) do
    File.close(file_descriptor)
  end
end
