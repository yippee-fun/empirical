# -*- encoding: utf-8 -*-
# stub: pretty_please 0.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "pretty_please".freeze
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "funding_uri" => "https://github.com/sponsors/joeldrapper", "homepage_uri" => "https://github.com/joeldrapper/pretty_please", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/joeldrapper/pretty_please" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Joel Drapper".freeze, "Marco Roth".freeze]
  s.date = "2025-02-11"
  s.description = "Print Ruby objects as Ruby".freeze
  s.email = ["joel@drapper.me".freeze, "marco.roth@intergga.ch".freeze]
  s.homepage = "https://github.com/joeldrapper/pretty_please".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Print Ruby objects as Ruby".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<dispersion>.freeze, ["~> 0.2"])
end
