defmodule Weaver.Personas do
  @moduledoc """
  `Weaver.Personas` handles converting from the persona interface to something `Weaver.LLM` can understand
  """

  defstruct base_dir: nil, name: nil

  def system_prompt(%{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "PERSONA.md"]) |> Path.expand())
  end

  def tools_available(%{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "persona.json"]) |> Path.expand())
    |> Jason.decode!(keys: :atoms)
    |> Map.fetch!(:tools)
  end

  def model(%{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "persona.json"]) |> Path.expand())
    |> Jason.decode!(keys: :atoms)
    |> Map.fetch!(:model)
  end
end
