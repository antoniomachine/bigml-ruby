# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bigml/version'

Gem::Specification.new do |spec|
  spec.name          = "bigml"
  spec.date          = '2016-06-14'
  spec.version       = BigML::VERSION
  spec.authors       = ["Tony J Martin"]
  spec.email         = ["toni.martin@gmail.com"]

  spec.summary       = %q{A Ruby wrapper for the BigML REST API}
  spec.description   = %q{BigML makes machine learning easy by taking care of the details required to add data-driven decisions and predictive power to your company. Unlike other machine learning services, BigML creates beautiful predictive models that can be easily understood and interacted with}
  spec.homepage      = "https://github.com/antoniomachine/bigml-ruby"

  spec.add_runtime_dependency     'rest-client', '~> 1.8'
  spec.add_runtime_dependency     'json', '~> 1.8'
  spec.add_runtime_dependency     'activesupport', '~> 3' 

  spec.files         = Dir['lib/   *.rb'] + Dir['lib/**/*.rb']
  spec.executables   = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.licenses    = ['MIT']

end
