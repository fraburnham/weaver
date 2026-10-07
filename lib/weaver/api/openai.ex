defmodule Weaver.Api.OpenAI do
  @moduledoc """
  Client for OpenAI apis

  ## Config

  | Key | Description | Default |
  |---|---|---|
  | `:project` | Project id for accounting/tracking. | Pulled from `WEAVER_OPENAI_PROJECT` |
  | `:api_key` | Key for authenticating with openai api. Optional, if not provided oidc will be used. | Pulled from `WEAVER_OPENAI_API_KEY` |
  | `:base_url` | Base url to use for the api. | Pulled from the persona at `api_config` |
  """

  use GenServer

  alias Weaver.Api.OpenAI.Oidc

  @behaviour Weaver.Api

  @impl true
  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config), do: {:ok, dbg(config), {:continue, :start_oidc}}

  @impl true
  def handle_continue(:start_oidc, config) do
    Oidc.start_link()
    {:noreply, config}
  end

  @impl true
  def handle_call({:chat, context}, _, config = %{base_url: base_url}) do
    %{project: project} =
      Application.get_env(:weaver, :openai) |> Enum.into(%{})

    api_key = get_api_key(config) |> dbg()

    tool_call_decoder =
      Weaver.Api.Bedrock.get_message_translator(&Jason.decode!(&1, keys: :atoms))

    tool_call_encoder = Weaver.Api.Bedrock.get_message_translator(&Jason.encode!/1)

    req_options =
      [
        url: "#{base_url}/v1/chat/completions",
        headers: %{"OpenAI-Project" => project, authorization: "Bearer #{api_key}"}
      ]
      |> Keyword.merge(Application.get_env(:weaver, :openai_req_options, []))

    %{
      choices: [%{message: message}],
      usage: %{prompt_tokens: input_tokens, total_tokens: total_tokens}
    } =
      Req.post!(
        req_options,
        json: tool_call_encoder.(context) |> Map.put(:stream, false) |> Map.put(:store, false),
        receive_timeout: :infinity,
        decoders: [json: &Jason.decode(&1, keys: :atoms)]
      ).body
      |> tool_call_decoder.()

    {:reply,
     %{
       message: message,
       input_tokens: input_tokens,
       total_tokens: total_tokens
     }, config}
  end

  defp get_api_key(%{api_key: api_key}) when is_binary(api_key), do: api_key

  defp get_api_key(_), do: Oidc.get_token()

  #
  # public api
  #

  @impl true
  def chat(context) do
    GenServer.call(__MODULE__, {:chat, context})
  end
end
