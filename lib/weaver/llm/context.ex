defmodule Weaver.LLM.Context do
  # TODO: This library manages context updates for the llm genserver
  def initial_context() do
    %{
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
