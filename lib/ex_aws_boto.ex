defmodule ExAws.Boto do
  require Logger
  require ExAws.Boto.Util

  alias ExAws.Boto.Util, as: Util
  alias ExAws.Boto.Operation, as: Operation
  alias ExAws.Boto.Shape, as: Shape

  @doc """
  Loads a service JSON spec from botocore, and generates client modules and objects.

  Accepts a list of services and API versions to load.

  ## Examples

      iex> ExAws.Boto.load(iam: "2010-05-08")
      :ok

      iex> ExAws.IAM.Api.list_users |> ExAws.IAM.Client.request()
      {:ok, [ ... ]}
  """
  @spec load(Keyword.t()) :: Macro.t()
  defmacro load(slugs) do
    slugs
    |> Enum.map(fn {service_atom, api_version} ->
      "#{service_atom}/#{api_version}"
    end)
    |> load_slugs()

    quote do
      nil
    end
  end

  @doc """
  If you already have a JSON spec file, you can use this to load it directly.
  """
  def generate_client(
        %{
          "version" => _version,
          "metadata" =>
            %{
              "serviceId" => service_id
            } = _metadata,
          "operations" => operations_map,
          "shapes" => shapes_map
        } = service_json
      ) do
    # Code.put_compiler_option(:tracers, [ExAws.Boto.Debug.CompileTracer])

    shapes_map
    |> Enum.each(fn {name, spec} ->
      service_json
      |> Shape.from_service_json(name, spec)
      |> Shape.generate_module()
      |> Code.compile_quoted(name)
    end)

    operations_specs =
      operations_map
      |> Enum.map(fn {_redundant_name, spec} ->
        Task.async(fn ->
          service_json
          |> Operation.from_service_json(spec)
        end)
      end)
      |> Enum.map(&Task.await(&1, 30_000))

    operations_specs
    |> Enum.each(fn op_spec ->
      op_spec
      |> Operation.generate_module()
      |> Code.compile_quoted(op_spec.name)
    end)

    api_mod = Util.module_name(service_id, nil)

    service_json
    |> generate_api_mod(operations_specs)
    |> Code.compile_quoted(api_mod |> inspect())

    client_mod = Util.module_name(service_id, "Client")

    service_json
    |> generate_client_mod()
    |> Code.compile_quoted(client_mod |> inspect())
  end

  defp load_slugs(slugs) when is_list(slugs) do
    slugs
    |> Enum.each(&load_slug/1)
  end

  defp load_slug(slug) when is_binary(slug) do
    botocore_path = Mix.Project.deps_paths() |> Map.get(:botocore)
    base_dir = "#{botocore_path}/botocore/data/#{slug}"

    %{
      "metadata" => %{
        "serviceId" => service_id
      }
    } = service = "#{base_dir}/service-2.json" |> load_service_file

    if function_exported?(ExAws.Boto.Util.module_name(service_id), :__info__, 1) == false do
      paginators = "#{base_dir}/paginators-1.json" |> load_service_file
      examples = "#{base_dir}/examples-1.json" |> load_service_file
      waiters = "#{base_dir}/waiters-2.json" |> load_service_file

      service
      |> Map.put("pagination", Map.get(paginators, "pagination", %{}))
      |> Map.put("examples", Map.get(examples, "examples", %{}))
      |> Map.put("waiters", Map.get(waiters, "waiters", %{}))
      |> generate_client
    end

    :ok
  end

  defp generate_api_mod(
         %{
           "version" => _version,
           "metadata" =>
             %{
               "serviceId" => service_id
             } = _metadata
         } = service_json,
         operations
       ) do
    api_mod = Util.module_name(service_id, nil)

    docs =
      service_json
      |> Map.get("documentation")
      |> ExAws.Boto.DocParser.doc_to_markdown()

    quote do
      defmodule unquote(api_mod) do
        @moduledoc unquote(docs)

        unquote_splicing(
          operations
          |> Enum.map(&Operation.generate_operation/1)
        )
      end
    end
  end

  defp generate_client_mod(
         %{
           "version" => _version,
           "metadata" =>
             %{
               "serviceId" => service_id
             } = _metadata,
           "pagination" => pagination
         } = service_json
       ) do
    client_mod = Util.module_name(service_id, "Client")

    quote do
      defmodule unquote(client_mod) do
        @spec stream(struct()) :: Enumerable.t()
        def stream(request, extra_config \\ [])

        unquote_splicing(
          pagination
          |> Enum.map(fn pagination ->
            ExAws.Boto.Stream.generate_paginator(service_json, pagination)
          end)
        )

        def stream(_, _) do
          raise "Stream not implemented"
        end

        def request(input, extra_config \\ []) do
          operation = ExAws.Boto.Operation.make_operation(input)
          response = ExAws.request(operation, extra_config)
          ExAws.Boto.Operation.parse_response(input, response)
        end

        def request!(input, extra_config \\ []) do
          case request(input, extra_config) do
            {:ok, response} -> response
            {:error, e} -> throw(e)
          end
        end
      end
    end
  end

  defp load_service_file(full_path) do
    full_path
    |> File.read()
    |> case do
      {:ok, contents} -> Jason.decode!(contents)
      _ -> %{}
    end
  end
end
