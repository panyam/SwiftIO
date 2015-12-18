#
# Be sure to run `pod lib lint SwiftIO.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "SwiftIO"
  s.version          = "0.0.1"
  s.summary          = "A simple wrapper around servers built on sockets to hide all the messy details."

  # This description is used to generate tags and improve search results.
  s.description      = <<-DESC
                        A painful part of developing servers is decoupling underlying transport from the stream handling.  
                        This gets worse with asynchronous IO where socket streams need to be bound to some event loop.
                        This pod takes care off all that and exposes a simple Connection interface that needs to be implemented
                        to process requests for any given protoocol.
                       DESC

  s.homepage         = "https://github.com/panyam/SwiftIO"
  s.license          = 'MIT'
  s.author           = { "Sriram Panyam" => "sri.panyam@gmail.com" }
  s.source           = { :git => "https://github.com/panyam/SwiftIO.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  # s.platform     = :osx, '10.9'
  # s.osx.platform     = :osx, '10.0'
  s.requires_arc = true

  s.source_files = 'Sources/**/*'
  s.resource_bundles = {
    'SwiftIO' => ['Pod/Assets/*.png']
  }

  s.public_header_files = 'Sources/*.h'
 # s.frameworks = 'CoreFoundation'
  # s.dependency 'AFNetworking', '~> 2.3'
end
