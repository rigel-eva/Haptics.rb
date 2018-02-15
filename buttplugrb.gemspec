load 'lib/buttplugrb/VERSION'
Gem::Specification.new do |s|
    s.name  ="buttplugrb"
    s.version=Buttplug::VERSION
    s.date="2018-02-14"
    s.summary="Buttplug Client Library"
    s.add_runtime_dependency "faye-websocket", [">=0.10.7"]
    s.add_runtime_dependency "eventmachine",[">=1.2.5"]
    s.add_runtime_dependency "json",[">=2.0.2"]
    s.authors = ["Nora Maguire"]
    s.email = "eva@rigel.moe"
    s.require_paths = ["lib", "bin", "examples"]
    s.files = ["CODE_OF_CONDUCT.md",
                "README.md",
                "Rakefile",
                "lib/buttplugrb.rb",
                "lib/buttplugrb/VERSION",
                "examples/Vibrate.rb"]
    s.homepage = "http://rubygems.org/gems/#{s.name}"
    s.license = "MIT"
end