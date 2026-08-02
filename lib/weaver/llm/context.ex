defmodule Weaver.LLM.Context do
  # TODO: This library manages context updates for the llm genserver
  def initial_context() do
    %{
      # TODO: model from config/input
      model: "gemma4:e2b",
      messages: [
        %{
          role: "system",
          # TODO: pull from config
          content: "This is only a system prompt test"
        }
      ],
      tools: []
    }
  end
end
