# weaver v0.1.0 - API Reference

## Modules

- [Weaver](Weaver.md)
- [Weaver.Api](Weaver.Api.md): `Weaver.Api` is a behaviour that describes an api `Weaver.LLM` can use

- [Weaver.Api.Anthropic](Weaver.Api.Anthropic.md): Client for anthropic messages api. Built on https://anthropix.hexdocs.pm/Anthropix.html

- [Weaver.Api.Bedrock](Weaver.Api.Bedrock.md): Client for AWS Bedrock api. Built on https://ex-aws-bedrock.hexdocs.pm/ExAws.Bedrock.html

- [Weaver.Api.Bedrock.Request](Weaver.Api.Bedrock.Request.md): `Weaver.Api.Bedrock.Request` handles converting sso credentials to something for ExAws and
wraps ExAws.Bedrock.request to inject those creds when calling Bedrock.

- [Weaver.Api.BedrockMock](Weaver.Api.BedrockMock.md): Mock AWS Bedrock api

- [Weaver.Api.Ollama](Weaver.Api.Ollama.md): Ollama api client

- [Weaver.Api.OllamaMock](Weaver.Api.OllamaMock.md): Mock Ollama api client

- [Weaver.Api.OpenAI](Weaver.Api.OpenAI.md): Client for OpenAI apis

- [Weaver.Application](Weaver.Application.md): The entrypoint for the application

- [Weaver.CLI](Weaver.CLI.md): `Weaver.CLI` handles displaying messages to the user in the terminal.
- [Weaver.CLI.ANSI](Weaver.CLI.ANSI.md): ANSI control sequences not provided by IO.ANSI
- [Weaver.CLI.ANSI.Macros](Weaver.CLI.ANSI.Macros.md): Helpers to reduce boilerplate for handling ANSI control sequences

- [Weaver.CLI.IO](Weaver.CLI.IO.md): Allows the user prompt to be handled async. Relies on `Weaver.CLI.Term` for configuring the terminal.
- [Weaver.CLI.SlashCommands](Weaver.CLI.SlashCommands.md): Helpers for `Weaver.CLI` slash commands like /exit, /clear, etc.

- [Weaver.History](Weaver.History.md): Persists conversation messages to JSONL files.
- [Weaver.LLM](Weaver.LLM.md): Maintains conversation context and manages LLM interactions.
- [Weaver.Personas](Weaver.Personas.md): `Weaver.Personas` handles loading persona details from persona.json and PERSONA.md files.
- [Weaver.Tools](Weaver.Tools.md): Manages tool execution and responses.
- [Weaver.Tools.Tool](Weaver.Tools.Tool.md): A behaviour for implementing tools as elixir modules

