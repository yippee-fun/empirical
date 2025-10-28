# -*- encoding: utf-8 -*-
# stub: difftastic 0.7.0 x86_64-linux lib

Gem::Specification.new do |s|
  s.name = "difftastic".freeze
  s.version = "0.7.0"
  s.platform = "x86_64-linux".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/joeldrapper/difftastic-ruby/releases", "homepage_uri" => "https://github.com/joeldrapper/difftastic-ruby", "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Joel Drapper".freeze]
  s.bindir = "exe".freeze
  s.date = "2025-05-24"
  s.email = ["joel@drapper.me".freeze]
  s.executables = ["difft".freeze]
  s.files = ["exe/difft".freeze]
  s.homepage = "https://github.com/joeldrapper/difftastic-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Integrate Difftastic with the RubyGems infrastructure.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<pretty_please>.freeze, [">= 0"])
end
