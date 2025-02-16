Pod::Spec.new do |s|
  s.name         = 'CloudServiceKit'
  s.version      = '1.0.4'
  s.license = 'MIT'
  s.requires_arc = true
  s.source = {:git => "https://github.com/alexiscn/CloudServiceKit.git", :tag => "#{s.version}"}

  s.summary = 'CloudServiceKit'
  s.homepage = 'https://github.com/alexiscn/CloudServiceKit'
  s.author       = { 'alexiscn' => 'https://github.com/alexiscn' }
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '14.0'
  s.source_files = 'Sources/*.swift'
  s.dependency 'OAuthSwift'
  s.swift_versions = ['5.1', '5.2', '5.3', '5.4', '5.5']
  
end
