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

# TODO: move this somewhere else
defmodule Atomize do
  @moduledoc """
  Convert stuff to atoms
  """

  def map_keys(n) when is_nil(n), do: n

  def map_keys(s) when is_struct(s) do
    Map.from_struct(s) |> map_keys
  end

  def map_keys(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      if is_atom(k) do
        {k, handle_value(v)}
      else
        {String.to_atom(k), handle_value(v)}
      end
    end
  end

  def map_keys(maps) when is_list(maps) do
    Enum.map(maps, &map_keys(&1))
  end

  defp handle_value(v) when is_map(v), do: map_keys(v)
  defp handle_value(v) when is_list(v), do: Enum.map(v, &handle_value/1)
  defp handle_value(v), do: v
end

defmodule Weaver.Api.Bedrock do
  @moduledoc """
  Client for AWS Bedrock api
  """

  @behaviour Weaver.Api

  # TODO: is this an approprate use of the `start_link` name?
  def start_link(),
    do:
      DynamicSupervisor.start_child(
        Weaver.DynamicSupervisor,
        {Weaver.Api.Bedrock.Request,
         struct!(Weaver.Api.Bedrock.Request, Application.get_env(:weaver, :bedrock))}
      )

  def tool_call_parser(updater) do
    fn req_resp ->
      parse_tool_calls(req_resp, updater)
    end
  end

  def parse_tool_calls(
        resp = %{choices: [%{message: %{tool_calls: [%{function: %{arguments: _}} | _]}} | _]},
        updater
      ) do
    update_in(
      resp,
      [
        :choices,
        Access.all(),
        :message,
        :tool_calls,
        Access.all(),
        :function,
        :arguments
      ],
      fn arguments ->
        updater.(arguments)
      end
    )
  end

  def parse_tool_calls(req = %{messages: [%{role: _} | _]}, updater) do
    update_in(
      req,
      [
        :messages,
        Access.filter(fn el ->
          is_map_key(el, :tool_calls)
        end),
        :tool_calls,
        Access.all(),
        :function,
        :arguments
      ],
      fn arguments ->
        updater.(arguments)
      end
    )
  end

  def parse_tool_calls(any, _), do: any

  def chat(data = %{model: model}) do
    tool_call_decoder = Weaver.Api.Bedrock.tool_call_parser(&Jason.decode!(&1, keys: :atoms))
    tool_call_encoder = Weaver.Api.Bedrock.tool_call_parser(&Jason.encode!/1)

    %{
      choices: [%{message: message}],
      usage: %{prompt_tokens: input_tokens, total_tokens: total_tokens}
    } =
      case ExAws.Bedrock.invoke_model(model, tool_call_encoder.(data))
           |> Weaver.Api.Bedrock.Request.request() do
        {:ok, response} ->
          response
          |> Atomize.map_keys()
          |> tool_call_decoder.()
      end

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: total_tokens
    }
  end
end

defmodule Weaver.Api.BedrockMock do
  @moduledoc """
  Mock AWS Bedrock api
  """

  @behaviour Weaver.Api

  def start_link(), do: nil

  def chat(req = %{messages: messages}) do
    tool_call_encoder = Weaver.Api.Bedrock.tool_call_parser(&Jason.encode!/1)
    tool_call_decoder = Weaver.Api.Bedrock.tool_call_parser(&Jason.decode!(&1, keys: :atoms))

    tool_call_encoder.(req)

    %{
      choices: [%{message: message}],
      usage: %{prompt_tokens: input_tokens, total_tokens: total_tokens}
    } =
      File.read!(
        if List.last(messages, %{role: "assistant"})[:role] === "tool" do
          "dev/bedrock-response.json"
        else
          "dev/bedrock-tool-response.json"
        end
      )
      |> Jason.decode!(keys: :atoms)
      |> tool_call_decoder.()

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: total_tokens
    }
  end
end
