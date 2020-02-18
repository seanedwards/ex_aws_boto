defmodule ExAws.Boto.QueryTest do
  use ExUnit.Case

  @metadata %{
    "apiVersion" => "YYYY-MM-DD",
    "endpointPrefix" => "unittests",
    "globalEndpoint" => "unittests.example.com",
    "protocol" => "query",
    "serviceAbbreviation" => "IAM",
    "serviceFullName" => "ExAws Boto Unit Tests",
    "serviceId" => "UnitTest",
    "signatureVersion" => "v1",
    "uid" => "unittest-YYYY-MM-DD",
    "xmlNamespace" => "https://unittests.example.com/doc/YYYY-MM-DD/"
  }

  @example %{
    "input" => %{
      "UnitTest" => "some unit test"
    },
    "output" => %{
      "TestResult" => true
    },
    "title" => "Run A Test",
    "description" => "Runs a unit test"
  }

  @sample_spec %{
    "version" => "2.0",
    "metadata" => @metadata,
    "operations" => %{
      "UnitTestOperation" => %{
        "name" => "UnitTestOperation",
        "http" => %{
          "method" => "POST",
          "requestUri" => "/"
        },
        "input" => %{"shape" => "UnitTestOperationRequest"},
        "output" => %{
          "shape" => "UnitTestOperationResponse",
          "resultWrapper" => "UnitTestOperationResult"
        },
        "errors" => [
          %{"shape" => "NoSuchUnitTestException"}
        ],
        "documentation" => "Does a unit test"
      }
    },
    "shapes" => %{
      "UnitTestOperationRequest" => %{
        "type" => "structure",
        "members" => %{
          "UnitTest" => %{
            "shape" => "UnitTestId"
          }
        }
      },
      "UnitTestId" => %{
        "type" => "string"
      },
      "UnitTestOperationResponse" => %{
        "type" => "structure",
        "members" => %{
          "TestResult" => %{
            "shape" => "TestResult"
          }
        }
      },
      "TestResult" => %{
        "type" => "boolean"
      }
    },
    "pagination" => %{},
    "examples" => %{
      "UnitTestOperation" => [
        @example
      ]
    }
  }

  ExAws.Boto.generate_client(@sample_spec)

  test "parses operations" do
    op_spec = ExAws.UnitTest.UnitTestOperation.op_spec()

    assert op_spec ==
             %ExAws.Boto.Operation{
               api_mod: ExAws.UnitTest.Api,
               client_mod: ExAws.UnitTest.Client,
               documentation: "Does a unit test",
               errors: [ExAws.UnitTest.NoSuchUnitTestException],
               examples: [@example],
               http: %{"method" => "POST", "requestUri" => "/"},
               input: ExAws.UnitTest.UnitTestOperationRequest,
               metadata: @metadata,
               method: :unit_test_operation,
               module: ExAws.UnitTest.UnitTestOperation,
               name: "UnitTestOperation",
               output: ExAws.UnitTest.UnitTestOperationResponse,
               output_wrapper: "UnitTestOperationResult",
               protocol: ExAws.Boto.Protocol.Query
             }
  end

  test "produces request objects" do
    request = ExAws.UnitTest.Api.unit_test_operation(unit_test: "some test")

    assert request == %ExAws.UnitTest.UnitTestOperation{
             input: %ExAws.UnitTest.UnitTestOperationRequest{
               unit_test: "some test"
             }
           }
  end

  test "parses response objects" do
    request = ExAws.UnitTest.Api.unit_test_operation(unit_test: "some test")

    # Just pretend we do an ExAws request here

    xml = """
    <UnitTestOperationResponse>
      <UnitTestOperationResult>
        <TestResult>true</TestResult>
      </UnitTestOperationResult>
    </UnitTestOperationResponse>
    """

    {:ok, response} = ExAws.Boto.Operation.parse_response(request, {:ok, %{body: xml}})

    assert response == %ExAws.UnitTest.UnitTestOperationResponse{
             test_result: true
           }
  end
end
