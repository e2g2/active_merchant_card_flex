# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "active_merchant_card_flex/version"

Gem::Specification.new do |s|
  s.name        = "active_merchant_card_flex"
  s.version     = ActiveMerchantCardFlex::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Stephen St. Martin"]
  s.email       = ["kuprishuz@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{CardFlex support for ActiveMerchant}
  s.description = %q{Provide support for CardFlex's standard integration and stored profile tokenization integrations.'}

  s.rubyforge_project = "active_merchant_card_flex"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'activemerchant', '>= 1.20.0'
  s.add_dependency 'activesupport', '>= 3.1.0'
  s.add_dependency 'money'

  s.add_development_dependency 'actionpack'
  s.add_development_dependency 'mocha'
end
