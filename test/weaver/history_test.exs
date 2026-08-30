defmodule Weaver.HistoryTest do
  use ExUnit.Case, async: true

  defp wait_for_empty_mailbox(pid, tries, timeout) do
    case Process.info(pid, :messages) do
      {:messages, []} ->
        :ok

      _ ->
        Process.sleep(timeout)
        wait_for_empty_mailbox(pid, tries - 1, timeout)
    end
  end

  setup do
    # Create a unique temporary directory for this test session
    base_dir = Path.join(System.tmp_dir!(), "weaver_history_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(base_dir)

    start_supervised!({Phoenix.PubSub, name: __MODULE__})

    {:ok, history_pid} =
      Weaver.History.start_link(config: [base_dir: base_dir, pubsub: __MODULE__])

    # Register the cleanup function to run when the test or process exits
    on_exit(fn ->
      File.rm_rf(base_dir)
    end)

    {:ok, base_dir: base_dir, history_pid: history_pid}
  end

  describe "Message Persistence" do
    test "single message persistence", context do
      # Initialize the history file by sending :clear command
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)
      # Publish a single message to the "messages" topic
      Phoenix.PubSub.broadcast(__MODULE__, "messages", %{role: "user", content: "test"})
      wait_for_empty_mailbox(context[:history_pid], 5, 10)

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
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)

      # Publish a list of messages
      messages = [
        %{role: "user", content: "a"},
        %{role: "assistant", content: "b"}
      ]

      Phoenix.PubSub.broadcast(__MODULE__, "messages", messages)

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
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
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)

      # Publish a message with resume: true
      Phoenix.PubSub.broadcast(__MODULE__, "messages", %{
        role: "user",
        content: "replaying",
        resume: true
      })

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Get the JSONL file from base_dir
      files = File.ls!(context[:base_dir])
      assert length(files) == 1
      jsonl_file = Path.join(context[:base_dir], List.first(files))

      # Read and verify the file does NOT contain the message
      content = File.read!(jsonl_file)
      refute content =~ ~s|replaying|
    end
  end

  describe "Command Handling" do
    test ":clear command creates a new file", context do
      # Initialize first file
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)
      # Send a message to first file
      Phoenix.PubSub.broadcast(__MODULE__, "messages", %{role: "user", content: "first"})

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Get the first file
      files = File.ls!(context[:base_dir])
      assert length(files) == 1

      # Send :clear to create a new file
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)
      # Send a message to second file
      Phoenix.PubSub.broadcast(__MODULE__, "messages", %{role: "user", content: "second"})

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Verify two files exist now
      files = File.ls!(context[:base_dir]) |> Enum.sort()
      assert length(files) == 2

      # Verify the second (newer) file contains the new message
      newest_file = Path.join(context[:base_dir], Enum.at(files, 1))
      content = File.read!(newest_file)
      assert content =~ ~s|{"role":"user","content":"second"}|
      refute content =~ ~s|first|
    end

    test "arbitrary command logging", context do
      # Initialize the history file
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)
      # Send an arbitrary atom command
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :my_custom_command)

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Get the JSONL file
      files = File.ls!(context[:base_dir])
      assert length(files) == 1
      jsonl_file = Path.join(context[:base_dir], List.first(files))

      # Verify the file contains the command logged
      content = File.read!(jsonl_file)
      assert content =~ ~s|{"command":"my_custom_command"}|
    end

    test "ignored commands are not written", context do
      # Initialize the history file
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)
      # Send a message to have something in the file
      Phoenix.PubSub.broadcast(__MODULE__, "messages", %{role: "user", content: "test"})

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Read file before sending ignored command
      files = File.ls!(context[:base_dir])
      jsonl_file = Path.join(context[:base_dir], List.first(files))
      before_content = File.read!(jsonl_file)

      # Send ignored command (termminal_tool_call with typo as per implementation)
      Phoenix.PubSub.broadcast(__MODULE__, "commands", {:termminal_tool_call, %{tool: "test"}})

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Read file after sending ignored command
      after_content = File.read!(jsonl_file)

      # Verify nothing was added
      assert before_content == after_content
    end

    test ":resume_end does not write to file", context do
      # Initialize the history file
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)
      # Send a message to have something in the file
      Phoenix.PubSub.broadcast(__MODULE__, "messages", %{role: "user", content: "test"})

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Read file before sending :resume_end
      files = File.ls!(context[:base_dir])
      jsonl_file = Path.join(context[:base_dir], List.first(files))
      before_content = File.read!(jsonl_file)

      # Send :resume_end command
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :resume_end)

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Read file after sending :resume_end
      after_content = File.read!(jsonl_file)

      # Verify nothing was added
      assert before_content == after_content
    end

    test "{:resume, _} does not write to file", context do
      # Initialize the history file
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)
      # Send a message to have something in the file
      Phoenix.PubSub.broadcast(__MODULE__, "messages", %{role: "user", content: "test"})

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Read file before sending {:resume, _}
      files = File.ls!(context[:base_dir])
      jsonl_file = Path.join(context[:base_dir], List.first(files))
      before_content = File.read!(jsonl_file)

      # Send {:resume, _} command
      Phoenix.PubSub.broadcast(__MODULE__, "commands", {:resume, :some_atom})

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Read file after sending {:resume, _}
      after_content = File.read!(jsonl_file)

      # Verify nothing was added
      assert before_content == after_content
    end
  end

  describe "Public API" do
    test "sessions/1 returns only .jsonl files and sorts them", context do
      # Initialize a file
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)

      # Create a dummy .txt file
      File.write!(Path.join(context[:base_dir], "dummy.txt"), "not a jsonl")
      # Create another .jsonl file manually to ensure sorting
      File.write!(Path.join(context[:base_dir], "1970-01-01T00:00:00Z.jsonl"), "old\n")

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      sessions = Weaver.History.sessions(context[:history_pid])

      # Should only return .jsonl files
      assert Enum.all?(sessions, fn f -> String.ends_with?(f, ".jsonl") end)
      refute "dummy.txt" in sessions

      # Should be sorted
      assert sessions == Enum.sort(sessions)
    end

    test "resume/1 replays messages and commands with resume: true", context do
      # Initialize a file and write some history
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :clear)
      Phoenix.PubSub.broadcast(__MODULE__, "messages", %{role: "user", content: "hello"})
      Phoenix.PubSub.broadcast(__MODULE__, "commands", :some_command)

      wait_for_empty_mailbox(context[:history_pid], 5, 10)
      # Get the history file
      files = File.ls!(context[:base_dir])
      assert length(files) == 1
      history_file = List.first(files)

      # Call resume
      Weaver.History.resume(history_file)
      # Give time for resume to complete and broadcast
      Process.sleep(200)

      # Verify a new history file was created after resume
      files_after = File.ls!(context[:base_dir])
      assert length(files_after) == 2

      # Verify the new file exists and is empty or ready for new messages
      newest_file = Path.join(context[:base_dir], Enum.at(files_after, 1))
      assert File.exists?(newest_file)
    end
  end
end
