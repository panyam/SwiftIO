#
# Be sure to run `pod lib lint SwiftSocketServer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "SwiftSocketServer"
  s.version          = "0.0.1"
  s.summary          = "A simple wrapper around servers built on sockets to hide all the messy details."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
                        A painful part of developing servers is decoupling underlying transport from the stream handling.  
                        This gets worse with asynchronous IO where socket streams need to be bound to some event loop.
                        This pod takes care off all that and exposes a simple Connection interface that needs to be implemented
                        to process requests for any given protoocol.
                       DESC

  s.homepage         = "https://github.com/panyam/SwiftSocketServer"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Sriram Panyam" => "sri.panyam@gmail.com" }
  s.source           = { :git => "https://github.com/panyam/SwiftSocketServer.git", :tag => s.version.to_s }

  # s.ios.platform     = :ios, '8.0'
  # s.osx.platform     = :osx, '10.0'
  s.requires_arc = true

  s.source_files = 'Sources/**/*'
  s.resource_bundles = {
    'SwiftSocketServer' => ['Pod/Assets/*.png']
  }

  s.public_header_files = 'SwiftSocketServer/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
