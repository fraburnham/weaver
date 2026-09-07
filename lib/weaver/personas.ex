defmodule Weaver.Personas do
  @moduledoc """
  `Weaver.Personas` handles loading persona details from persona.json and PERSONA.md files.

  A persona is built from a `persona.json` and a `PERSONA.md` in a directory named for the persona.

  #### `persona.json`

  ```json
  {
    "model": "model-name-or-id",
    "api": "Api.Module.Name",
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

  @spec system_prompt(t()) :: String.t()
  def system_prompt(%Personas{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "PERSONA.md"]) |> Path.expand())
  end

  @spec tools_available(t()) :: list()
  def tools_available(%Personas{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "persona.json"]) |> Path.expand())
    |> Jason.decode!(keys: :atoms)
    |> Map.fetch!(:tools)
  end

  @spec model(t()) :: {String.t(), module()}
  def model(%Personas{base_dir: base_dir, name: persona}) do
    %{model: model, api: api} =
      File.read!(Path.join([base_dir, persona, "persona.json"]) |> Path.expand())
      |> Jason.decode!(keys: :atoms)

    {model, Module.concat([api])}
  end

  @spec model_options(t()) :: map()
  def model_options(%Personas{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "persona.json"]) |> Path.expand())
    |> Jason.decode!(keys: :atoms)
    |> Map.take([:context_window, :temperature, :top_p, :top_k, :output_tokens])
  end
end
