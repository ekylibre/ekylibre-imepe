# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'ekylibre_imepe/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'ekylibre_imepe'
  s.version     = EkylibreImepe::VERSION
  s.authors     = ['Ekylibre developers']
  s.email       = ['dev@ekylibre.com']
  s.homepage    = 'https://ekylibre.com'
  s.summary     = 'Integration of IMEPE-related data'
  s.description = 'Ekylibre plugin for sync data between MesParcelles and Ekylibre'
  s.license     = 'Proprietary'

  s.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.rdoc', 'Capfile']
  s.require_path = ['lib']
  s.test_files = Dir['test/**/*']
  s.add_dependency 'vcr'
  s.add_dependency 'webmock'
end
