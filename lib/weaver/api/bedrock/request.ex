defmodule Weaver.Api.Bedrock.Request do
  @moduledoc """
  `Weaver.Api.Bedrock.Request` handles converting sso credentials to something for ExAws and
  wraps ExAws.Bedrock.request to inject those creds when calling Bedrock.
  """
  use GenServer

  alias Weaver.Api.Bedrock.Request

  defstruct credential_process: nil,
            access_key_id: nil,
            expiration: nil,
            secret_access_key: nil,
            session_token: nil

  def start_link(config = %Request{}),
    do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %Request{credential_process: credential_process})
      when not is_nil(credential_process) do
    send(self(), :update_credentials)

    {:ok, config}
  end

  @impl true
  def handle_info(:update_credentials, %Request{credential_process: credential_process}) do
    # TODO: set the refresh
    {:noreply, update_credentials(credential_process)}
  end

  @impl true
  def handle_call(
        :get_credentials,
        _from,
        config = %Request{
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          session_token: session_token
        }
      ) do
    # TODO: handle expired creds
    {:reply,
     [
       access_key_id: access_key_id,
       secret_access_key: secret_access_key,
       security_token: session_token
     ], config}
  end

  defp update_credentials(credential_process) do
    creds = credential_process.()

    %Request{
      credential_process: credential_process,
      access_key_id: creds["AccessKeyId"],
      expiration: creds["Expiration"],
      secret_access_key: creds["SecretAccessKey"],
      session_token: creds["SessionToken"]
    }
  end

  def awscli_credential_process do
    Exile.stream(["aws", "configure", "export-credentials"])
    |> Enum.into([])
    |> Enum.filter(fn chunk ->
      case chunk do
        # TODO: ignoring the exit status is sloppy
        {:exit, {:status, _}} -> false
        _ -> true
      end
    end)
    |> IO.iodata_to_binary()
    |> Jason.decode!()
  end

  def request(op, config_overrides \\ []) do
    ExAws.Bedrock.request(
      op,
      Keyword.merge(config_overrides, GenServer.call(__MODULE__, :get_credentials))
    )
  end
end
