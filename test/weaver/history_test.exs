defmodule Weaver.HistoryTest do
  use ExUnit.Case
  import ExUnit.Setup

  setup do
    # Create a unique temporary directory for this test session
    base_dir = Path.join(System.tmp_dir!(), "weaver_history_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(base_dir)

    # Start the History GenServer with the temp directory
    # Note: Using a unique name or ensuring singleton behavior is handled by the GenServer
    # For now, we use the default name as defined in the module
    {:ok, _pid} = Weaver.History.start_link(base_dir: base_dir)

    # Register the cleanup function to run when the test or process exits
    on_exit(fn ->
      File.rm_rf(base_dir)
    end)

    {:ok, base_dir: base_dir}
  end

  test "temp directory is created during setup" do
    assert File.exist?(base_dir)
  end
end
