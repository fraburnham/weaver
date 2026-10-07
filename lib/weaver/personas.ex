defmodule Weaver.Personas do
  @moduledoc """
  `Weaver.Personas` handles loading persona details from persona.json and PERSONA.md files.

  A persona is built from a `persona.json` and a `PERSONA.md` in a directory named for the persona.

  #### `persona.json`

  ```json
  {
    "model": "model-name-or-id",
    "api": "Api.Module.Name",
    "api_config": {
      "base_url": "https://example.com"
    }
    "context_window": 128000,
    "output_tokens": 16000,
    "temperature": 0.6,
    "top_p": 0.95,
    "top_k": 20,
    "tools": [
      "list",
      "of",
      "tools",
      "model",
      "can",
      "use"
    ]
  }
  ```

  | Key | Description |
  |-----|-------------|
  | `"model"` | The name or id of the model in a format that the api client can use |
  | `"api"` | The elixir module to use as the api backend that implements the `Weaver.Api` behaviour |
  | `"api_config"` | Optional configuration for the api module |
  | `"context_window"` | The maximum number of tokens the context is allowed to use |
  | `"output_tokens"` | The maximum number of output tokens to generate |
  | `"temperature"` | Temperature value to pass to the model |
  | `"top_p"` | Top p value to pass to the model |
  | `"top_k"` | Top k value to pass to the model |
  | `"tools"` | A list of tool names this persona is allowed to call |

  #### `PERSONA.md`

  The `PERSONA.md` file is used as the system prompt. It can be empty.

  #### Config

  | Key | Description |
  |-----|-------------|
  | `:base_dir` | The base directory to search for personas |
  | `:name` | The name of the persona must match its dirname in the personas base dir |
  """

  alias Weaver.Personas

  defstruct base_dir: nil, name: nil

  @type t :: %Personas{base_dir: String.t(), name: String.t()}

  @type model_options :: %{
          optional(:context_window) => non_neg_integer(),
          optional(:output_tokens) => non_neg_integer(),
          optional(:temperature) => float(),
          optional(:top_p) => float(),
          optional(:top_k) => non_neg_integer()
        }

  @spec system_prompt(t()) :: String.t()
  def system_prompt(p = %Personas{}) do
    read_persona_file(p, "PERSONA.md")
  end

  @spec tools_available(t()) :: [String.t()]
  def tools_available(p = %Personas{}) do
    read_persona_file(p, "persona.json")
    |> Jason.decode!(keys: :atoms)
    |> Map.fetch!(:tools)
  end

  @spec model(t()) :: {String.t(), module()}
  def model(p = %Personas{}) do
    %{model: model, api: api} =
      read_persona_file(p, "persona.json")
      |> Jason.decode!(keys: :atoms)

    {model, Module.concat([api])}
  end

  @spec model_options(t()) :: model_options()
  def model_options(p = %Personas{}) do
    read_persona_file(p, "persona.json")
    |> Jason.decode!(keys: :atoms)
    |> Map.take([:context_window, :temperature, :top_p, :top_k, :output_tokens])
  end

  @spec api_config(t()) :: map()
  def api_config(p = %Personas{}) do
    read_persona_file(p, "persona.json")
    |> Jason.decode!(keys: :atoms)
    |> Map.get(:api_config, %{})
  end

  defp read_persona_file(%Personas{base_dir: base_dir, name: persona}, file) do
    File.read!(Path.join([base_dir, persona, file]) |> Path.expand())
  end
end
