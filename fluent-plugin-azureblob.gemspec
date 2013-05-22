# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-azureblob"
  spec.version       = "0.0.1"
  spec.authors       = ["Takekazu Omi"]
  spec.email         = ["takekazuomi@gmail.com"]
  spec.description   = %q{Write a gem description}
  spec.summary       = %q{Write a gem summary}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "fluentd", "~> 0.10.0"
  spec.add_runtime_dependency "yajl-ruby", "~> 1.0"
  spec.add_runtime_dependency "azure"
  spec.add_runtime_dependency "azure_blob_extentions"
  spec.add_runtime_dependency "fluent-mixin-config-placeholders", "~> 0.2.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
