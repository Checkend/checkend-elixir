defmodule Checkend.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/Checkend/checkend-elixir"

  def project do
    [
      app: :checkend,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "Checkend",
      description: "Elixir SDK for Checkend error monitoring",
      source_url: @source_url,
      homepage_url: "https://checkend.com"
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {Checkend.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.14", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Checkend" => "https://checkend.com"
      },
      maintainers: ["Simon Chiu <simon@checkend.com>"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/getting-started.md",
        "guides/phoenix-integration.md",
        "guides/testing.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        Core: [Checkend],
        "Plug Integration": [Checkend.Plugs.ErrorHandler],
        Testing: [Checkend.Testing]
      ],
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <meta name="keywords" content="elixir, error tracking, exception monitoring, phoenix error reporting, plug error handler, elixir sdk, error monitoring">
    """
  end

  defp before_closing_head_tag(_), do: ""

  defp before_closing_body_tag(:html) do
    """
    <div style="text-align: center; padding: 20px; border-top: 1px solid #e0e0e0; margin-top: 40px; font-size: 14px; color: #666;">
      <p>
        <a href="https://checkend.com" style="color: #4a90d9; text-decoration: none; font-weight: bold;">Checkend</a> —
        Simple, powerful error monitoring for your applications.
      </p>
      <p style="margin-top: 8px;">
        Project sponsored by <a href="https://furvur.com" style="color: #4a90d9; text-decoration: none; font-weight: bold;">Furvur</a>
      </p>
    </div>
    """
  end

  defp before_closing_body_tag(_), do: ""
end
