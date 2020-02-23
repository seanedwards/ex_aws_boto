defmodule ExAws.Boto.Operation do
  @moduledoc false
  alias ExAws.Boto.Util, as: Util
  alias ExAws.Boto.Shape

  @callback op_spec() :: %ExAws.Boto.Operation{}

  defstruct [
    :name,
    :module,
    :protocol,
    :method,
    :http,
    :input,
    :output,
    :output_wrapper,
    :errors,
    :documentation,
    :metadata,
    :examples,
    :api_mod,
    :client_mod
  ]

  def from_service_json(
        %{
          "metadata" => %{"serviceId" => service_id, "protocol" => protocol} = service_meta,
          "examples" => examples
        },
        %{"name" => name} = op_def
      ) do
    %__MODULE__{
      name: name,
      module: Util.module_name(service_id, name),
      protocol:
        case protocol do
          "query" -> ExAws.Boto.Protocol.Query
          "json" -> ExAws.Boto.Protocol.Json
        end,
      method: Util.key_to_atom(name),
      documentation:
        op_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      http: Map.get(op_def, "http"),
      input:
        with {:ok, input} <- Map.fetch(op_def, "input") do
          Util.module_name(service_id, input)
        else
          _ -> nil
        end,
      output:
        with {:ok, output} <- Map.fetch(op_def, "output") do
          Util.module_name(service_id, output)
        else
          _ -> nil
        end,
      output_wrapper:
        with {:ok, output} <- Map.fetch(op_def, "output"),
             {:ok, wrapper} <- Map.fetch(output, "resultWrapper") do
          wrapper
        else
          _ -> nil
        end,
      errors:
        op_def
        |> Map.get("errors", [])
        |> Enum.map(&Util.module_name(service_id, &1)),
      metadata: service_meta,
      examples: Map.get(examples, name, []),
      api_mod: Util.module_name(service_id),
      client_mod: Util.module_name(service_id, "Client")
    }
  end

  alias ExAws.Boto.Util, as: Util

  @doc """
  Converts an AWS API operation struct into one suitable for ExAws to use directly.
  """
  def make_operation(op) do
    op.__struct__.op_spec().protocol.make_operation(op)
  end

  def parse_response(op, response) do
    op.__struct__.op_spec().protocol.parse_response(op, response)
  end

  def generate_module(
        %ExAws.Boto.Operation{
          module: op_mod,
          input: input_mod
        } = op_def
      )
      when op_mod != nil do
    quote do
      defmodule unquote(op_mod) do
        @moduledoc false
        @behaviour ExAws.Boto.Operation

        defstruct unquote(
                    if input_mod do
                      quote do: [:input]
                    else
                      quote do: []
                    end
                  )

        @impl ExAws.Boto.Operation
        def op_spec(), do: unquote(Macro.escape(op_def))
      end
    end
  end

  def generate_operation(
        %ExAws.Boto.Operation{
          module: op_mod,
          method: op_name,
          input: input_type,
        } = op_spec
      )
      when op_mod != nil and input_type != nil do
    input_spec =Shape.generate_type_spec(input_type)

    quote do
      @doc unquote(generate_docs(op_spec))
      @spec unquote(op_name)(unquote(input_type).params()) :: %unquote(op_mod){
              input: unquote(input_spec)
            }
      def unquote(op_name)(input \\ []) do
        %unquote(op_mod){
          input: unquote(input_type).new(input)
        }
        |> ExAws.Boto.Operation.make_operation()
      end
    end
  end

  def generate_operation(
        %ExAws.Boto.Operation{
          module: op_mod,
          method: op_name,
          input: nil
        } = op_spec
      )
      when op_mod != nil do
    quote do
      @doc unquote(generate_docs(op_spec))
      @spec unquote(op_name)() :: %unquote(op_mod){}
      def unquote(op_name)() do
        %unquote(op_mod){}
        |> ExAws.Boto.Operation.make_operation()
      end
    end
  end


  defp generate_docs(
         %ExAws.Boto.Operation{
           documentation: html,
           examples: examples
         } = op_def
       )
       when is_binary(html) do
    examples_html =
      case examples do
        [] ->
          ""

        examples ->
          examples
          |> Enum.reduce(
            """
            ## Examples
            """,
            fn %{"title" => title, "description" => description} = example, html ->
              """
              #{html}

              ### #{title}

              #{ExAws.Boto.DocParser.doc_to_markdown(description)}

                  #{generate_doc_tests(op_def, example) |> String.replace("\n", "\n    ")}

              """
            end
          )
      end

    """
    #{html}
    #{generate_doc_return(op_def)}
    #{examples_html}
    """
  end

  defp generate_docs(_) do
    false
  end

  defp generate_doc_return(%ExAws.Boto.Operation{
         output: output_mod
       })
       when output_mod == nil do
    ""
  end

  defp generate_doc_return(%ExAws.Boto.Operation{
         output: output_mod
       }) do
    """
    ## Returns

        #{Shape.generate_type_spec(output_mod) |> codify() |> String.replace("\n", "\n    ")}

    """
  end

  defp generate_doc_tests(
         %ExAws.Boto.Operation{
           method: method,
           client_mod: client_mod,
           api_mod: api_mod
         } = op_def,
         %{
           "input" => example_inputs
         } = example
       ) do
    args =
      example_inputs
      |> Enum.map(fn {arg_name, arg_val} ->
        {arg_name |> Util.key_to_atom(), arg_val}
      end)

    code_input =
      quote do
        unquote(api_mod).unquote(method)(unquote(args))
        |> unquote(client_mod).request!()
      end
      |> codify()

    """
    #{iex_prompt(code_input)}
    #{generate_doc_tests_output(op_def, example)}
    """
  end

  defp generate_doc_tests(
         %ExAws.Boto.Operation{
           method: op_method,
           api_mod: api_mod
         } = op_def,
         example
       ) do
    code_input =
      quote do
        unquote(api_mod).unquote(op_method)()
      end
      |> codify()

    """
    #{iex_prompt(code_input)}
    #{generate_doc_tests_output(op_def, example)}
    """
    |> String.replace("\n", "\n    ")
  end

  defp generate_doc_tests_output(
         %ExAws.Boto.Operation{
           output: output_mod
         },
         %{
           "output" => sample_output
         } = _example
       )
       when output_mod != nil do
    output_mod.new(sample_output)
    |> Macro.escape()
    |> codify()
  end

  defp generate_doc_tests_output(
         %{} = _op_def,
         %{} = _example
       ) do
    inspect({:ok, nil})
  end

  defp codify(block) do
    block
    |> Macro.to_string()
    |> Code.format_string!(locals_without_perens: true)
    |> IO.iodata_to_binary()
  end

  defp iex_prompt(str) do
    "iex> #{String.replace(str, "\n", "\n...> ")}"
  end
end
