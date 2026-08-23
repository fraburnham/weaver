defmodule Weaver.TUI.Term do
  @on_load :load_nifs

  def load_nifs do
    :erlang.load_nif("priv/term", 0)
  end

  def set_config(_config), do: :erlang.nif_error(:nif_not_loaded)
  def get_config, do: :erlang.nif_error(:nif_not_loaded)
  def get_flag_values, do: :erlang.nif_error(:nif_not_loaded)
end
