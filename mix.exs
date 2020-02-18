defmodule ExAwsBoto.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_aws_boto,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Generate ExAws clients from Botocore JSON specs",
      licenses: ["MIT"],
      links: %{
        github: "https://github.com/seanedwards/ex_aws_boto"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:mojito, "~> 0.6"},
      {:jason, "~> 1.1"},
      {:sweet_xml, "~> 0.6"},
      {:configparser_ex, "~> 2.0"},
      {:ex_aws, "~> 2.1"},
      {:floki, "~> 0.25"},
      {:botocore, github: "boto/botocore", compile: false, app: false, runtime: false}
    ]
  end
end
