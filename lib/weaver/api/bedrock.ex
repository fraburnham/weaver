defmodule Weaver.Api.Bedrock do
  def parse_tool_calls(updater) do
    fn req_resp ->
      case req_resp do
        # Update the tool calls in a bedrock response
        %{choices: [%{message: %{tool_calls: _}} | _]} ->
          update_in(
            req_resp,
            [:choices, Access.all(), :message, :tool_calls, Access.all(), :function, :arguments],
            fn arguments ->
              updater.(arguments)
            end
          )

        r ->
          r
      end
    end
  end

  end
end

defmodule Weaver.Api.BedrockMock do
  def chat(%{messages: messages}, _) do
    tool_call_decoder = Weaver.Api.Bedrock.parse_tool_calls(&Jason.decode!/1)

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

# TODO: utils with rename_keys and deep_take (that flattens structure)
