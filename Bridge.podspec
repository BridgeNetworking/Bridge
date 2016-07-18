#
#  Be sure to run `pod spec lint Bridge.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "Bridge"
  s.version      = "0.4.1"
  s.summary      = "Extremely Extensible Typed JSON HTTP Networking in Swift"
  s.homepage     = "https://github.com/rawrjustin/Bridge"
  s.license      = "MIT"
  s.author             = { "Justin Huang" => "justingotemail@gmail.com" }
  s.social_media_url   = "http://twitter.com/rawrjustin"
  s.source       = { :git => "https://github.com/rawrjustin/Bridge.git", :tag => "#{s.version}" }
  s.source_files  = "Bridge/*"

  # Deployment Platforms and Target Versions
  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'

  s.public_header_files = "Bridge/*.h"

end
