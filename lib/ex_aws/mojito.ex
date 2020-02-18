defmodule ExAws.Mojito do
  @behaviour ExAws.Request.HttpClient

  defp mojito_opts, do: Application.get_env(:ex_aws, :mojito_opts, [])

  @impl true
  def request(method, url, body \\ nil, headers \\ [], opts \\ []) do
    Mojito.request(
      method: method,
      url: url,
      body: body,
      headers: clean_headers(headers),
      opts: opts ++ mojito_opts()
    )
  end

  defp clean_headers(headers) do
    Enum.map(headers, fn {key, value} ->
      {String.downcase(key), to_string(value)}
    end)
  end
end

