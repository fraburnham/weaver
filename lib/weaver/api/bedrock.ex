defmodule Weaver.Api.Bedrock do
  def handle_tool_call(tool_call = %{function: function = %{arguments: argumments}}) do
    # TODO: Pretty sure this is where to handle the llm giving back a shitty tool call
    %{tool_call | function: %{function | arguments: Jason.decode!(argumments)}}
  end

  def parse_tool_requests(
        response = %{choices: [choice = %{message: message = %{tool_calls: tool_calls}}]}
      ) do
    %{response | choices: [%{choice | message: %{message | tool_calls: tool_calls}}]}
  end

  def parse_tool_requests(response) do
    response
  end
end

defmodule Weaver.Api.BedrockMock do
  def chat(%{messages: messages}, _) do
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
      |> Weaver.Api.Bedrock.parse_tool_requests()

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: total_tokens
    }
  end
end

# TODO: utils with rename_keys and deep_take (that flattens structure)
