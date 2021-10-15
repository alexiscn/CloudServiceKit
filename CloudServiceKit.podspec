Pod::Spec.new do |s|
  s.name         = 'CloudServiceKit'
  s.version      = '1.0.3'
  s.license = 'MIT'
  s.requires_arc = true
  s.source = {:git => "https://github.com/alexiscn/CloudServiceKit.git", :tag => "#{s.version}"}

  s.summary = 'CloudServiceKit'
  s.homepage = 'https://github.com/alexiscn/CloudServiceKit'
  s.author       = { 'alexiscn' => 'https://github.com/alexiscn' }
  s.platform     = :ios
  s.ios.deployment_target = '13.0'
  s.source_files = 'Sources/*.swift'
  s.dependency 'OAuthSwift'
  
end
