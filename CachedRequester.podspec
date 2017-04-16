Pod::Spec.new do |spec|
  spec.name = "CachedRequester"
  spec.version = "1.0.1"
  spec.summary = "Network requester with the ability to cache the results and auto-purge them if needed."
  spec.homepage = "https://github.com/mnvoh/CachedRequester"
  spec.license = { type: 'MIT', file: 'LICENSE.md' }
  spec.authors = { "Milad Nozari" => 'mnvoh90@gmail.com' }
  spec.social_media_url = "https://twitter.com/mnvoh"

  spec.platform = :ios, "9.1"
  spec.requires_arc = true
  spec.source = { git: "https://github.com/mnvoh/CachedRequester.git", tag: "v#{spec.version}" }
  spec.source_files = "CachedRequester/*.{h,swift}"
end
