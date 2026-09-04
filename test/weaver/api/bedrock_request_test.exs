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

  describe "handle_info/2 - Credential Updates" do
    test "handles :update_credentials message" do
      fake_credential_process = fn ->
        %{
          "AccessKeyId" => "updated_key",
          "SecretAccessKey" => "updated_secret",
          "SessionToken" => "updated_token",
          "Expiration" => "2025-06-01T00:00:00Z"
        }
      end

      config = %Request{credential_process: fake_credential_process}

      assert {:ok, _pid} = GenServer.start_link(Request, config, name: :test_handle_info)

      # Credentials should be loaded from init
      credentials = GenServer.call(:test_handle_info, :get_credentials)

      assert credentials == [
               access_key_id: "updated_key",
               secret_access_key: "updated_secret",
               security_token: "updated_token"
             ]

      # Send another :update_credentials message to test handle_info
      send(:test_handle_info, :update_credentials)

      # Give the GenServer time to process the message
      Process.sleep(100)

      # Credentials should still be valid after re-update
      credentials = GenServer.call(:test_handle_info, :get_credentials)

      assert credentials == [
               access_key_id: "updated_key",
               secret_access_key: "updated_secret",
               security_token: "updated_token"
             ]

      GenServer.stop(:test_handle_info)
    end

    test "update_credentials with valid JSON updates state correctly" do
      fake_credential_process = fn ->
        %{
          "AccessKeyId" => "A",
          "SecretAccessKey" => "S",
          "SessionToken" => "T",
          "Expiration" => "E"
        }
      end

      config = %Request{credential_process: fake_credential_process}

      assert {:ok, _pid} = GenServer.start_link(Request, config, name: :test_valid_json)

      # Wait for credentials to be loaded
      Process.sleep(100)

      credentials = GenServer.call(:test_valid_json, :get_credentials)

      assert credentials == [
               access_key_id: "A",
               secret_access_key: "S",
               security_token: "T"
             ]

      GenServer.stop(:test_valid_json)
    end

    test "update_credentials with missing keys sets nil values" do
      fake_credential_process = fn ->
        %{
          "AccessKeyId" => "A"
          # Missing SecretAccessKey, SessionToken, Expiration
        }
      end

      config = %Request{credential_process: fake_credential_process}

      # Starting the GenServer with partial credentials should succeed
      # but missing keys will be nil (map access returns nil for missing keys)
      assert {:ok, _pid} = GenServer.start_link(Request, config, name: :test_missing_keys)

      # Give the GenServer time to process credentials
      Process.sleep(100)

      credentials = GenServer.call(:test_missing_keys, :get_credentials)

      # access_key_id should be set, others should be nil
      assert credentials == [
               access_key_id: "A",
               secret_access_key: nil,
               security_token: nil
             ]

      GenServer.stop(:test_missing_keys)
    end
  end

  describe "handle_call/3 - API Wrapper Functions" do
    test "get_credentials returns credentials with security_token mapped from session_token" do
      # Setup: GenServer state populated with credentials
      state = %Request{
        credential_process: fn -> %{} end,
        access_key_id: "AKIAIOSFODNN7EXAMPLE",
        secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        session_token: "FwoGZXIvYXdzEBYaDH...",
        expiration: "2025-12-31T23:59:59Z"
      }

      # Call handle_call directly with pre-populated state
      result = Request.handle_call(:get_credentials, :from, state)

      # Expectation: Returns {:reply, [access_key_id: ..., secret_access_key: ..., security_token: ...], state}
      assert {:reply, credentials, ^state} = result

      assert credentials == [
               access_key_id: "AKIAIOSFODNN7EXAMPLE",
               secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
               security_token: "FwoGZXIvYXdzEBYaDH..."
             ]
    end

    test "get_credentials maps session_token from state to security_token in reply" do
      # Note: Ensure session_token in state maps to security_token in reply (per ExAws requirements)
      state = %Request{
        credential_process: nil,
        access_key_id: "test_key",
        secret_access_key: "test_secret",
        session_token: "test_session_token_value",
        expiration: nil
      }

      result = Request.handle_call(:get_credentials, :from, state)

      assert {:reply, credentials, _state} = result

      # Verify security_token is present (not session_token)
      assert {:security_token, "test_session_token_value"} in credentials
      refute Enum.any?(credentials, fn {key, _val} -> key == :session_token end)
    end
  end
end
