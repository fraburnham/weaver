ExUnit.start()

Application.put_env(:weaver, :ollama, %{base_url: "http://localhost:11434"})
Application.put_env(:weaver, :req_options, [plug: {Req.Test, :ollama_api}])
