defmodule Atomize do
  @moduledoc """
  Convert stuff to atoms
  """

  def map_keys(n) when is_nil(n), do: n

  def map_keys(s) when is_struct(s) do
    Map.from_struct(s) |> map_keys
  end

  def map_keys(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      if is_atom(k) do
        {k, handle_value(v)}
      else
        {String.to_atom(k), handle_value(v)}
      end
    end
  end

  def map_keys(maps) when is_list(maps) do
    Enum.map(maps, &map_keys(&1))
  end

  defp handle_value(v) when is_map(v), do: map_keys(v)
  defp handle_value(v) when is_list(v), do: Enum.map(v, &handle_value/1)
  defp handle_value(v), do: v
end
