defmodule Weaver.Api.OpenAI.Oidc.Plug do
  @moduledoc """
  Handle the local server for oidc flow
  """
  use Plug.Router

  @port 1455

  def start_link(),
    do:
      DynamicSupervisor.start_child(
        Weaver.DynamicSupervisor,
        {Plug.Cowboy, plug: Weaver.Api.OpenAI.Oidc.Plug, scheme: :http, options: [port: 1455]}
      )

  plug(:match)
  plug(:fetch_query_params)
  plug(:dispatch)

  get "/auth/callback" do
    send(Weaver.Api.OpenAI.Oidc, {:callback, conn.query_params})
    send_resp(conn, 200, "You can close this tab")
  end

  match _ do
    send_resp(conn, 404, [])
  end
end

defmodule Weaver.Api.OpenAI.Oidc do
  @moduledoc """
  https://auth.openai.com/.well-known/openid-configuration
  """

  use GenServer

  @callback_url "http://localhost:1455/auth/callback"
  @authorization_url "https://auth.openai.com/api/accounts/authorize"
  @token_url "https://auth.openai.com/api/accounts/oauth/token"
  # TODO: do I need all these scopes?
  @scopes "openid profile email offline_access"
  @client_id "app_EMoamEEZ73f0CkXaXp7hrann"

  defstruct code_key: nil,
            state_id: nil,
            tokens: nil,
            reply_to: nil

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_info(:start_oidc, state = %__MODULE__{reply_to: _}) do
    code_key =
      :crypto.strong_rand_bytes(32)
      |> Base.url_encode64(padding: false)

    state_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, _} = Weaver.Api.OpenAI.Oidc.Plug.start_link()
    open(authorization_url(code_key, state_id))

    {:noreply, %__MODULE__{state | code_key: code_key, state_id: state_id}}
  end

  @impl true
  def handle_info(
        {:callback, %{"code" => code_resp, "state" => state_resp}},
        state = %__MODULE__{reply_to: reply_to, code_key: code_key, state_id: state_id}
      ) do
    # TODO: confirm the states match
    tokens = exchange_code_for_token(code_key, state_id, code_resp)
    # TODO: confirm the token is valid? Am I able to w/o a public key?
    GenServer.reply(reply_to, tokens["access_token"])

    {:noreply, %__MODULE__{state | tokens: tokens}}
  end

  @impl true
  def handle_call(:get_token, from, state = %__MODULE__{}) do
    # TODO! this should check if there is already a valid token and just reply with that instead (a caching updater)
    send(self(), :start_oidc)

    {:noreply, %__MODULE__{state | reply_to: from}}
  end

  defp authorization_url(code_key, state_id) do
    %URI{
      URI.parse(@authorization_url)
      | query:
          URI.encode_query(%{
            response_type: "code",
            client_id: @client_id,
            redirect_uri: @callback_url,
            scope: @scopes,
            state: state_id,
            code_challenge: :crypto.hash(:sha256, code_key) |> Base.encode16(case: :lower),
            code_challenge_method: "S256",
            originator: "weaver"
          })
    }
    |> URI.to_string()
  end

  defp open(url) do
    Task.start(fn ->
      {_, 0} =
        case :os.type() do
          {:unix, :darwin} ->
            System.cmd("open", [url])

          {:unix, _} ->
            if System.find_executable("xdg-open") do
              System.cmd("xdg-open", [url])
            end

          {:win32, _} ->
            System.cmd("cmd", ["/c", "start", url])
        end
    end)
  end

  defp exchange_code_for_token(code_key, state_id, code) do
    Req.post!(
      @token_url,
      form: [
        grant_type: "authorization_code",
        code: code,
        redirect_uri: @callback_url,
        client_id: @client_id,
        code_verifier: code_key
      ]
    ).body
  end

  def get_token do
    GenServer.call(__MODULE__, :get_token, :infinity)
  end
end
