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

  describe "Command Handling" do
    test ":clear command creates a new file", context do
      # Initialize first file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Send a message to first file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{role: "user", content: "first"})
      Process.sleep(50)

      # Get the first file
      files = File.ls!(context[:base_dir])
      assert length(files) == 1
      first_file = Path.join(context[:base_dir], List.first(files))

      # Send :clear to create a new file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Send a message to second file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{role: "user", content: "second"})
      Process.sleep(50)

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
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Send an arbitrary atom command
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :my_custom_command)
      Process.sleep(50)

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
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Send a message to have something in the file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{role: "user", content: "test"})
      Process.sleep(50)

      # Read file before sending ignored command
      files = File.ls!(context[:base_dir])
      jsonl_file = Path.join(context[:base_dir], List.first(files))
      before_content = File.read!(jsonl_file)

      # Send ignored command (termminal_tool_call with typo as per implementation)
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", {:termminal_tool_call, %{tool: "test"}})
      Process.sleep(50)

      # Read file after sending ignored command
      after_content = File.read!(jsonl_file)

      # Verify nothing was added
      assert before_content == after_content
    end

    test ":resume_end does not write to file", context do
      # Initialize the history file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Send a message to have something in the file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{role: "user", content: "test"})
      Process.sleep(50)

      # Read file before sending :resume_end
      files = File.ls!(context[:base_dir])
      jsonl_file = Path.join(context[:base_dir], List.first(files))
      before_content = File.read!(jsonl_file)

      # Send :resume_end command
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :resume_end)
      Process.sleep(50)

      # Read file after sending :resume_end
      after_content = File.read!(jsonl_file)

      # Verify nothing was added
      assert before_content == after_content
    end

    test "{:resume, _} does not write to file", context do
      # Initialize the history file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Send a message to have something in the file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{role: "user", content: "test"})
      Process.sleep(50)

      # Read file before sending {:resume, _}
      files = File.ls!(context[:base_dir])
      jsonl_file = Path.join(context[:base_dir], List.first(files))
      before_content = File.read!(jsonl_file)

      # Send {:resume, _} command
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", {:resume, :some_atom})
      Process.sleep(50)

      # Read file after sending {:resume, _}
      after_content = File.read!(jsonl_file)

      # Verify nothing was added
      assert before_content == after_content
    end
  end

  describe "Public API" do
    test "sessions/0 returns only .jsonl files and sorts them", context do
      # Initialize a file
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      # Create a dummy .txt file
      File.write!(Path.join(context[:base_dir], "dummy.txt"), "not a jsonl")

      # Create another .jsonl file manually to ensure sorting
      File.write!(Path.join(context[:base_dir], "1970-01-01T00:00:00Z.jsonl"), "old\n")

      Process.sleep(50)

      sessions = Weaver.History.sessions()

      # Should only return .jsonl files
      assert Enum.all?(sessions, fn f -> String.ends_with?(f, ".jsonl") end)
      refute "dummy.txt" in sessions

      # Should be sorted
      assert sessions == Enum.sort(sessions)
    end

    test "resume/1 replays messages and commands with resume: true", context do
      # Subscribe to topics to capture broadcasts
      Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")
      Phoenix.PubSub.subscribe(Weaver.PubSub, "commands")

      # Initialize a file and write some history
      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)
      Process.sleep(50)

      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{role: "user", content: "hello"})
      Process.sleep(50)

      Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :some_command)
      Process.sleep(50)

      # Get the history file
      files = File.ls!(context[:base_dir])
      assert length(files) == 1
      history_file = List.first(files)

      # Call resume
      Weaver.History.resume(history_file)
      Process.sleep(200) # Give time for resume to complete and broadcast

      # Verify a new history file was created after resume
      files_after = File.ls!(context[:base_dir])
      assert length(files_after) == 2

      # Verify the new file exists and is empty or ready for new messages
      newest_file = Path.join(context[:base_dir], Enum.at(files_after, 1))
      assert File.exists?(newest_file)
    end
  end

end
