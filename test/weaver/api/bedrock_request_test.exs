defmodule Weaver.Api.Bedrock.RequestTest do
  use ExUnit.Case, async: false

  alias Weaver.Api.Bedrock.Request

  describe "init/1" do
    test "initializes with credential_process" do
      fake_credential_process = fn ->
        %{
          "AccessKeyId" => "test_access_key",
          "SecretAccessKey" => "test_secret_key",
          "SessionToken" => "test_session_token",
          "Expiration" => "2024-01-01T00:00:00Z"
        }
      end

      config = %Request{credential_process: fake_credential_process}

      # Start the GenServer - init/1 sends :update_credentials to self()
      # This triggers handle_info to load credentials
      assert {:ok, _pid} = GenServer.start_link(Request, config, name: :test_request_init)

      # After init completes and handle_info processes :update_credentials,
      # credentials should be available
      credentials = GenServer.call(:test_request_init, :get_credentials)

      assert credentials == [
               access_key_id: "test_access_key",
               secret_access_key: "test_secret_key",
               security_token: "test_session_token"
             ]

      GenServer.stop(:test_request_init)
    end

    test "returns {:ok, config} and populates credentials from credential_process" do
      fake_credential_process = fn ->
        %{
          "AccessKeyId" => "fake_key",
          "SecretAccessKey" => "fake_secret",
          "SessionToken" => "fake_token",
          "Expiration" => "2025-12-31T23:59:59Z"
        }
      end

      config = %Request{credential_process: fake_credential_process}

      assert {:ok, _pid} = GenServer.start_link(Request, config, name: :test_request_state)

      # Verify credentials are loaded
      credentials = GenServer.call(:test_request_state, :get_credentials)

      assert credentials == [
               access_key_id: "fake_key",
               secret_access_key: "fake_secret",
               security_token: "fake_token"
             ]

      GenServer.stop(:test_request_state)
    end
  end
end
