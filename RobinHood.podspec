Pod::Spec.new do |s|
  s.name             = 'RobinHood'
  s.version          = '0.2.3'
  s.summary          = 'Observable data provider implementation with cache support.'

  s.description      = <<-DESC
  Library is aimed to solve a problem to display cached data when original one is fetched from data source. Currently there are two type of data providers. DataProvider implementation is aimed to manage identifiable list of entities while SingleValueProvider deals with single objects. Both types of data providers uses Core Data to store cached objects. Clients can subsribe for changes in data provider to update an interface as soon as fresh data is fetched from setup source.
                       DESC

  s.homepage         = 'https://github.com/soramitsu'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ERussel' => 'emkil.russel@gmail.com' }
  s.source           = { :git => 'https://github.com/soramitsu/robinhood-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.source_files = 'RobinHood/Classes/**/*'
  s.swift_version = '4.2'

  s.test_spec do |ts|
    ts.source_files = 'Tests/**/*.swift'
    ts.dependency 'FireMock'
    ts.resources = ['Tests/**/*.xcdatamodeld', 'Tests/**/*.json']
  end
  
end
