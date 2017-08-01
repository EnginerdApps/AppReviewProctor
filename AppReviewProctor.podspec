#
# Be sure to run `pod lib lint AppReviewProctor.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AppReviewProctor'
  s.version          = '0.1.0'
s.summary          = 'Provides bookkeeping support to decide when to ask the user whether to rate an app, in addition to the app store restrictions built in to SKStoreReviewController.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Apple provides SKStoreReviewController to provide SDK support for user app reviews.  Whether or not this will actually display an app review is governed by App Store Policy, and Apple leaves it up to the developer to use SKStoreReviewController "when it makes sense in the user experience flow of your app."  App Review Proctor provides a wrapper around SKStoreReviewController that supports various bookkeeping operations to help decide when it makes sense to request a review be displayed in your app.  If a user's device does not support SKStoreReviewController, an UIAlertController-based review interface is provided.
                       DESC

  s.homepage         = 'https://github.com/enginerdapps/AppReviewProctor'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Colin Van Dyke' => 'colin@enginerdapps.com' }
  s.source           = { :git => 'https://github.com/enginerdapps/AppReviewProctor.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'AppReviewProctor/Classes/**/*'
  
  # s.resource_bundles = {
  #   'AppReviewProctor' => ['AppReviewProctor/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
