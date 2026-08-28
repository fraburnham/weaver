defmodule Weaver.HistoryTest do
  use ExUnit.Case

  setup do
    # Create a unique temporary directory for this test session
    base_dir = Path.join(System.tmp_dir!(), "weaver_history_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(base_dir)

    # Start the History GenServer with the temp directory
    # Note: Using a unique name or ensuring singleton behavior is handled by the GenServer
    # For now, we use the default name as defined in the module
    {:ok, _pid} = Weaver.History.start_link(struct!(Weaver.History, %{base_dir: base_dir}))

    # Register the cleanup function to run when the test or process exits
    on_exit(fn ->
      File.rm_rf(base_dir)
    end)

    {:ok, base_dir: base_dir}
  end

  test "temp directory is created during setup", context do
    assert File.exists?(context[:base_dir])
  end

  describe "Message Persistence" do
    test "single message persistence", context do
      # Initialize the history file by sending :clear command
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Publish a single message to the "messages" topic
      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{role: "user", content: "test"})
      Process.sleep(50)

      # Get the JSONL file from base_dir
      files = File.ls!(context[:base_dir])
      assert length(files) == 1
      jsonl_file = Path.join(context[:base_dir], List.first(files))

      # Read and verify the file contains the encoded JSON
      content = File.read!(jsonl_file)
      assert content =~ ~s|{"role":"user","content":"test"}|
    end

    test "batch message persistence", context do
      # Initialize the history file by sending :clear command
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Publish a list of messages
      messages = [
        %{role: "user", content: "a"},
        %{role: "assistant", content: "b"}
      ]

      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", messages)
      Process.sleep(50)

      # Get the JSONL file from base_dir
      files = File.ls!(context[:base_dir])
      assert length(files) == 1
      jsonl_file = Path.join(context[:base_dir], List.first(files))

      # Read and verify the file contains both messages as separate lines
      content = File.read!(jsonl_file)
      assert content =~ ~s|{"role":"user","content":"a"}|
      assert content =~ ~s|{"role":"assistant","content":"b"}|
    end

    test "filtering resume: true messages", context do
      # Initialize the history file by sending :clear command
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Publish a message with resume: true
      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{
        role: "user",
        content: "replaying",
        resume: true
      })

      Process.sleep(50)

      # Get the JSONL file from base_dir
      files = File.ls!(context[:base_dir])
      assert length(files) == 1
      jsonl_file = Path.join(context[:base_dir], List.first(files))

      # Read and verify the file does NOT contain the message
      content = File.read!(jsonl_file)
      refute content =~ ~s|replaying|
    end
  end
end
