#require "bundler/gem_tasks"
desc "Our Default Task"
task :default do
    Rake::Task[:buildDevVersion].invoke
end
desc "Build the gem, and install it (primairly for testing)"
task :buildDevVersion do 
    sh %{gem uninstall buttplugrb}
    sh %{gem build buttplugrb.gemspec}
    sh %{gem install buttplugrb*.gem}
    sh %{rm buttplugrb*.gem}
end
task :getCurrentRelease do
    sh %{gem uninstall buttplugrb}
    sh %{gem install buttplugrb}
end
task :console do
    sh %{ruby bin/console}
end
task :buildDevandRun do
    Rake::Task[:buildDevVersion].invoke
    Rake::Task[:console].invoke
end
