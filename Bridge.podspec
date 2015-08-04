Pod::Spec.new do |s|
  s.name             = "Bridge"
  s.version          = "0.1"
  s.summary          = "Simple iOS Networking"
  s.homepage         = "https://github.com/zumper"
  s.license          = 'MIT'
  s.author           = { "Justin Huang" => "justin@zumper.com" }
  s.source           = { :git => "https://github.com/rawrjustin/Bridge.git" }
  s.social_media_url = 'https://twitter.com/zumper'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.frameworks = 'UIKit'
  s.source_files = "Bridge/*.swift"

end
