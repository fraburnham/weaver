defmodule Weaver.TUI.Term do
  @moduledoc """
  A terminal config and input library that is ligher than ratatui and more configurable than terminfo.
  """

  @on_load :load_nifs

  def load_nifs do
    weaver_dir = :code.priv_dir(:weaver)
    :ok = :erlang.load_nif(String.to_charlist("#{weaver_dir}/term"), 0)
  end

  def set_config(_config), do: :erlang.nif_error(:nif_not_loaded)
  def get_config, do: :erlang.nif_error(:nif_not_loaded)
  def get_flag_values, do: :erlang.nif_error(:nif_not_loaded)
  def attempt_read, do: :erlang.nif_error(:nif_not_loaded)
end
