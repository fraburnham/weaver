defmodule Weaver.Api do
  @callback start_link() :: tuple
  @callback chat(context :: map) :: map
end
