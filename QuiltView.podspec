#
# Be sure to run `pod lib lint QuiltView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'QuiltView'
  s.version          = '0.1.4'
  s.summary          = 'QuiltView is a subclass of UICollectionViewLayout that positions various sized cells in a quilt like pattern.'
  s.description      = <<-DESC
QuiltView will layout CollectionView cells with various widths and heights on the page. The cells are positioned in a quilt style layout so each cell fits next to the other cell, leaving only the space defined by the UIEdgeInsets. You can provide widths and heights that are not equal creating rectangular shapes or you can specify a width and height that matches to ensure the cells are square. This library is a port of the RFQuiltLayout developed by Bryce Redd. That project can be found here: https://github.com/bryceredd/RFQuiltLayout
                       DESC
  s.homepage         = 'https://github.com/facetdigital/QuiltView'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'jgroh9' => 'jgroh@facetdigital.com' }
  s.source           = { :git => 'https://github.com/facetdigital/QuiltView.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/FacetDigital'

  s.ios.deployment_target = '10.2'
  s.tvos.deployment_target = '10.1'

  s.source_files = 'QuiltView/Classes/*'
  
  # s.resource_bundles = {
  #   'QuiltView' => ['QuiltView/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
