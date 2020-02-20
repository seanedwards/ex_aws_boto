defmodule ExAwsBoto.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_aws_boto,
      version: "0.1.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      description: "Generate ExAws clients from Botocore JSON specs",
      elixirc_options: [
        warnings_as_errors: true
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mojito]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:jason, "~> 1.1"},
      {:sweet_xml, "~> 0.6"},
      {:ex_aws, "~> 2.1"},
      {:floki, "~> 0.25"},
      {:botocore, github: "boto/botocore", compile: false, app: false, runtime: false, optional: true, only: [:dev, :test]},
      {:mojito, "~> 0.6", optional: true, only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Sean Edwards <stedwards87+hex@gmail.com>"],
      links: %{
        github: "https://github.com/seanedwards/ex_aws_boto"
      }
    ]
  end

  defp docs do
    [
      main: "ExAws.Boto",
      extras: ["README.md"]
    ]
  end
end
