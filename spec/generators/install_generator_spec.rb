require "generators/leancss/install/install_generator"

RSpec.describe Leancss::Generators::InstallGenerator do
  def generate
    capture = StringIO.new
    $stdout = capture
    described_class.start([], destination_root: root.to_s)
  ensure
    $stdout = STDOUT
  end

  before do
    write("Gemfile", %(source "https://rubygems.org"\n\ngem "rails"\n))
    write(".gitignore", "/tmp/*\n")
  end

  it "adds the initializer, the stylesheets, Sass, and ignores the built files" do
    generate

    initializer = root.join("config/initializers/leancss.rb").read
    expect(initializer).to include(%("bootstrap" => { git: "https://github.com/twbs/bootstrap.git", tag: "v5.3.8" }))
    expect(initializer).to include(%(stylesheet_link_tag "lean/public"))
    expect(initializer).not_to include("gem:styler")

    stylesheets = Dir.glob("**/*", base: root.join("app/assets/stylesheets")).select { |path| path.end_with?(".scss") }
    expect(stylesheets).to contain_exactly(
      "public.scss", "public/_variables.scss", "public/_layout.scss", "public/_header.scss", "public/_typography.scss",
      "public/_footer.scss", "admin.scss", "admin/_variables.scss", "admin/_admin.scss"
    )

    expect(root.join("Gemfile").read).to include(%(gem "sass-embedded", "~> 1.93"))
    expect(root.join(".gitignore").read).to end_with("/app/assets/builds/lean\n")
  end

  it "writes settings that load and describe two builds" do
    generate
    app = Struct.new(:config).new(Struct.new(:leancss).new(ActiveSupport::OrderedOptions.new))
    stub_const("Rails", Module.new.tap { |rails| rails.define_singleton_method(:application) { app } })
    load root.join("config/initializers/leancss.rb").to_s

    configuration = Leancss::Configuration.new(app.config.leancss, root: root)
    expect(configuration.packages.map(&:name)).to eq(%w[ bootstrap core-styles-3 ])
    expect(configuration.builds.map { |build| [ build.name, build.sources.map(&:entry) ] }).to eq([ [ "public", %w[ public.scss ] ], [ "admin", %w[ admin.scss ] ] ])
  end

  it "sorts styler's admin layout into the admin build in apps using styler" do
    allow(Gem.loaded_specs).to receive(:key?).and_call_original
    allow(Gem.loaded_specs).to receive(:key?).with("styler").and_return(true)
    generate

    expect(root.join("config/initializers/leancss.rb").read).to include("gem:styler/app/views/layouts/admin_cs3*")
  end

  it "doesn't add Sass or the ignore line twice" do
    generate
    generate

    expect(root.join("Gemfile").read.scan("sass-embedded").size).to eq(1)
    expect(root.join(".gitignore").read.scan("/app/assets/builds/lean").size).to eq(1)
  end
end
