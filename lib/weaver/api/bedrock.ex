defmodule Weaver.Api.Bedrock do
  @moduledoc """
  Client for AWS Bedrock api
  """

  @behaviour Weaver.Api

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
