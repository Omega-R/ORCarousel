#
# Be sure to run `pod lib lint ORCarousel.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ORCarousel'
  s.version          = '1.0.1'
  s.summary          = 'ORCarousel by Omega.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
'This is the carousel by Omega company named \"ORCarousel\"'
                       DESC

  s.homepage         = 'https://github.com/Omega-R/ORCarousel'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Egor Lindberg' => 'egor.lindberg@omega-r.com' }
  s.source           = { :git => 'https://github.com/Omega-R/ORCarousel.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.swift_version = '5.0'

  s.source_files = 'Sources/ORCarousel/Classes/**/*'
  
  # s.resource_bundles = {
  #   'ORCarousel' => ['ORCarousel/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit'#, 'MapKit'
  s.dependency 'PureLayout'#, '~> 3.1.6'
end
