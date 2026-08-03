defmodule Weaver.Api.BedrockMock do
  def chat(%{messages: messages}, _) do
    response =
      File.read!(
        if List.last(messages, %{role: "assistant"})[:role] === "tool" do
          "dev/bedrock-response.json"
        else
          "dev/bedrock-tool-response.json"
        end
      )
      |> Jason.decode!(keys: :atoms)

    %{
      message: response[:choices] |> List.first!() |> Map.get(:message),
      input_tokens: response[:usage][:prompt_tokens],
      total_tokens: response[:usage][:total_tokens]
    }
  end
end

# TODO: utils with rename_keys and deep_take (that flattens structure)
