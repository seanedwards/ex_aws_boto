defmodule ExAws.Boto.Util do
  @doc """
  Converts a service ID and shape name into an Elixir module

  ## Examples
      iex> ExAws.Boto.Util.module_name("SomeService", "TestObject")
      ExAws.SomeService.TestObject
  """
  def module_name(service_id, shape \\ nil)

  def module_name(service_id, nil) do
    ["Elixir", "ExAws", Macro.camelize(service_id), "Api"]
    |> Enum.join(".")
    |> String.to_atom()
  end

  def module_name(service_id, %{"shape" => shape_name}) do
    module_name(service_id, shape_name)
  end

  def module_name(service_id, shape_name) when is_binary(shape_name) do
    ["Elixir", "ExAws", Macro.camelize(service_id), Macro.camelize(shape_name)]
    |> Enum.join(".")
    |> String.to_atom()
  end

  def module_name(_, module) when is_atom(module) do
    module
  end

  @doc """
  Converts a string key from an AWS spec into an atom,
  such as for a function call or struct property

  ## Examples

      iex> ExAws.Boto.Util.key_to_atom("UserName")
      :user_name

      iex> ExAws.Boto.Util.key_to_atom("NotificationARNs")
      :notification_arns

      iex> ExAws.Boto.Util.key_to_atom("TestARNs")
      :test_arns

      iex> ExAws.Boto.Util.key_to_atom("VpcID")
      :vpc_id
  """
  def key_to_atom("NotificationARNs"), do: :notification_arns

  def key_to_atom(key) when is_binary(key) do
    key
    |> to_charlist()
    |> underscorify([])
    |> :erlang.list_to_atom()
  end

  def key_to_atom(nil) do
    nil
  end

  @doc """
  Determines whether a single erlang character is a lowercase ASCII letter
  """
  defguard is_lower(letter) when letter >= 97 and letter <= 122

  @doc """
  Determines whether a single erlang character is an uppercase ASCII letter
  """
  defguard is_upper(letter) when letter >= 65 and letter <= 90

  defp underscorify([lower, upper | rest], acc) when is_lower(lower) and is_upper(upper) do
    # don't forget to append in reverse order
    underscorify(rest, [upper + 32, 95, lower | acc])
  end

  defp underscorify([upper | rest], acc) when is_upper(upper) do
    underscorify(rest, [upper + 32 | acc])
  end

  defp underscorify([lower | rest], acc) do
    underscorify(rest, [lower | acc])
  end

  defp underscorify([], acc) do
    acc
    |> Enum.reverse()
  end
end
