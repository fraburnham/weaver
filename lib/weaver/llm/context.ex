defmodule Weaver.LLM.Context do
  def initial_context(%{model: model}) do
    %{
      model: model,
      messages: [
        %{
          role: "system",
          # TODO: pull from config this and ask the tools module about its stuff (use call/cast or something so I can send it off as a message and the started process can
          # track where the tool root is instead of crossing config?)
          content: "This is only a system prompt test"
        }
      ],
      tools: []
    }
  end

  # TODO: get rid of this. Create a personas.ex module like tools.ex. It'll handle loading persona details. They'll be passed in to the llm service's startup.
end
