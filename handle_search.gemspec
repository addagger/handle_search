# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require "handle_search/version"

Gem::Specification.new do |s|
  s.name        = "handle_search"
  s.version     = HandleSearch::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Valery Kvon"]
  s.email       = ["addagger@gmail.com"]
  s.homepage    = %q{http://vkvon.ru/projects/handle_search}
  s.summary     = %q{Flexible search logic for ActiveRecord}
  s.description = %q{Represent search interface via ActiveModel instance}
  
  s.add_development_dependency "activerecord", ['>= 2.3.0']

  s.rubyforge_project = "handle_search"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.licenses = ['MIT']
  
end