defmodule ExAws.Boto.DocParser do
  @moduledoc false

  def doc_to_markdown(false), do: false
  def doc_to_markdown(nil), do: nil

  def doc_to_markdown(doc) do
    doc
    |> Floki.parse_fragment!()
    |> html_to_markdown()
  end

  @spec html_to_markdown(Floki.html_tree()) :: String.t()
  defp html_to_markdown({"code", _, html}) do
    "`#{html_to_markdown(html)}`"
  end

  defp html_to_markdown({"i", _, html}) do
    "*#{html_to_markdown(html)}*"
  end

  defp html_to_markdown({"a", [], html}) do
    "`#{Macro.underscore(html_to_markdown(html))}/1`"
  end

  defp html_to_markdown({"a", [{"href", href}], html}) do
    "[#{html_to_markdown(html)}](#{href})"
  end

  defp html_to_markdown({"p", _, paragraph}) do
    (paragraph
     |> html_to_markdown()) <> "\n\n"
  end

  defp html_to_markdown({"ul", _, paragraph}) do
    paragraph
    |> Enum.map(fn html -> html_to_markdown(html) end)
    |> Enum.join("\n")
  end

  defp html_to_markdown({"li", _, paragraph}) do
    "* #{html_to_markdown(paragraph)}"
  end

  defp html_to_markdown({"note", _, html}) do
    "> #{String.trim(html_to_markdown(html))}"
    |> String.replace("\n", "\n> ")
  end

  defp html_to_markdown({tag, _, content}) do
    "<#{tag}>#{html_to_markdown(content)}</#{tag}>"
  end

  defp html_to_markdown(html) when is_list(html) do
    html
    |> Enum.map(&html_to_markdown/1)
    |> Enum.join("")
  end

  defp html_to_markdown(text) when is_binary(text) do
    text
  end
end
