defmodule ExAws.Boto.Stream do
  @moduledoc false
  alias ExAws.Boto.Util, as: Util

  def generate_paginator(
        %{
          "metadata" => %{"serviceId" => service_id}
        } = _service_json,
        {op_name_str,
         %{
           "input_token" => input_token,
           "output_token" => output_token,
           "result_key" => result_key
         } = pagination}
      ) do
    op_mod = Util.module_name(service_id, op_name_str)
    input_token = Util.key_to_atom(input_token)
    output_token = Util.key_to_atom(output_token)

    quote do
      def stream(%unquote(op_mod){} = request, extra_config) do
        Stream.unfold(request, fn
          nil ->
            nil

          %unquote(op_mod){input: input} = arg ->
            arg
            |> request(extra_config)
            |> case do
              {:ok, %_{unquote(output_token) => nil} = reply} ->
                {reply, nil}

              {:ok, %_{unquote(output_token) => marker} = reply} ->
                next_arg = %unquote(op_mod){
                  request
                  | input: Map.put(input, unquote(input_token), marker)
                }

                {reply, next_arg}

              {:error, e} ->
                raise e
            end
        end)
        |> Stream.flat_map(
          unquote(
            case result_key do
              keys when is_list(keys) ->
                quote do
                  fn %_{} = result ->
                    unquote(keys |> Enum.map(&Util.key_to_atom/1))
                    |> Enum.flat_map(fn key ->
                      Map.get(result, key)
                    end)
                  end
                end

              key when is_binary(key) ->
                quote do
                  fn %_{unquote(Util.key_to_atom(result_key)) => results} ->
                    results
                  end
                end
            end
          )
        )
      end
    end
  end
end
