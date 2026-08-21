import Config

defmodule Weaver.Mock do
  # @behaviour Weaver.Tools.Tool

  def run(_tool_call) do
    "Ran!"
  end

  def definition do
    %{
      type: "function",
      function: %{
        name: "mock",
        description:
          "Call me to test that tool calling is working. You'll get back 'Ran!' if it is.",
        parameters: %{
          type: "object",
          properties: %{
            input: %{
              description: "Put whatever you want here. It's only a test.",
              type: "string"
            }
          },
          required: [
            "input"
          ],
          additionalProperties: false
        }
      }
    }
  end
end

config :weaver,
  tools: [tool_modules: %{"mock" => Weaver.Mock}, async: true],
  personas: [name: "agent.nu-testing"]
