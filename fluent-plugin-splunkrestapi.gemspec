# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-splunkrestapi"
  gem.version       = "0.0.1"
  gem.authors       = ["Youichi Fujimoto"]
  gem.email         = ["yofujimo@gmail.com"]
  gem.summary       = %q{Splunk REST API output plugin for Fluentd event collector}
  gem.description   = %q{Splunk REST API output plugin for Fluentd event collector}
  gem.homepage      = "https://github.com/fpt"
  gem.license       = 'Apache License, Version 2.0'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.rubyforge_project = "fluent-plugin-splunkrestapi"
  gem.add_development_dependency "fluentd"
  gem.add_development_dependency "net-http-persistent"
  gem.add_runtime_dependency "fluentd"
  gem.add_runtime_dependency "net-http-persistent"
end
