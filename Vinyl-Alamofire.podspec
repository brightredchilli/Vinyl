Pod::Spec.new do |s|
  s.name         = "Vinyl-Alamofire"
  s.version      = "0.1.2"
  s.summary      = "Network testing à la VCR in Swift"
  s.description  = "Vinyl-Alamofire is designed to automate replaying network requests and integrate seamlessly with Alamofire. It takes heavy inspiration from Vinyl"
  s.homepage     = "https://github.com/brightredchilli/Vinyl-Alamofire"
  s.author       = { 'brightredchilli' => '(email)' }
  s.license      = 'MIT'
  s.swift_version = '4.0'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '9.1'
  s.source       = { :git => "https://github.com/brightredchilli/Vinyl-Alamofire.git", :tag => s.version }
  s.source_files = "Vinyl/**/*"
end
