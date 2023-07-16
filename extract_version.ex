defmodule AssetBuilderVersion do
  def extract(nil) do
    nil
  end

  def extract({:config, _loc, code}) do
    [_app, opts] = code
    opts[:version]
  end
end

[config_path, app | _] = System.argv()

{_, _, ast} =
  File.read!(config_path)
  |> Code.string_to_quoted!()

version =
  ast
  |> Enum.find(fn {call, _, [ast_app | _]} ->
    call == :config && "#{ast_app}" == app
  end)
  |> AssetBuilderVersion.extract()

IO.puts(version)
