namespace :leancss do
  desc "Build the trimmed stylesheets into app/assets/builds/lean (BUILD=name for one)"
  task build: :environment do
    builds = Leancss.configuration.builds
    builds = builds.select { |build| build.name == ENV["BUILD"] } if ENV["BUILD"].present?
    builds.each { |build| puts build.run.summary }
  end

  desc "Show what trimming removes from each build, without writing anything (BUILD=name for one)"
  task report: :environment do
    builds = Leancss.configuration.builds
    builds = builds.select { |build| build.name == ENV["BUILD"] } if ENV["BUILD"].present?
    builds.each { |build| puts build.report.details, "" }
  end

  desc "Remove the built stylesheets and downloaded sources"
  task clobber: :environment do
    configuration = Leancss.configuration
    rm_rf configuration.output_dir
    rm_rf configuration.cache_dir
  end
end

# Production builds while precompiling, before Propshaft copies the assets.
# Adding prerequisites this way works whether Propshaft's tasks load first or not.
task "assets:precompile" => "leancss:build"
task "assets:clobber" => "leancss:clobber"
