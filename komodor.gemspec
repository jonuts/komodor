$:.unshift 'lib'
require "komodor/version"

Gem::Specification.new do |s|
  s.name     = "komodor"
  s.version  = Komodor::VERSION
  s.summary  = "Background process manager"
  s.homepage = "https://github.com/jonuts/komodor"
  s.email    = "jonah@honeyman.org"
  s.authors  = ["jonah honeyman"]
  s.has_rdoc = false

  s.files  = %W(README.md)
  s.files += Dir.glob("lib/**/*")
  s.files += Dir.glob("spec/**/*")

  s.description = s.summary
end
