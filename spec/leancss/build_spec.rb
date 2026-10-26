RSpec.describe Leancss::Build do
  let(:build) do
    Leancss::Configuration.new({ builds: { "site" => { css: %w[ a.css b.css ], safelist: %w[ kept ] } } }, root: root).builds.first
  end

  before do
    write("app/assets/stylesheets/a.css", "/*! license */\n.btn { color: red }\n.unused { color: blue }\n")
    write("app/assets/stylesheets/b.css", ".alert-danger { color: red } .alert-info { color: blue } .kept { x: y } .show { z: 1 }")
    write("app/views/home/index.html.erb", %(<a class="btn"><div class="alert alert-<%= kind %>">))
  end

  it "joins, trims and writes the file" do
    report = build.run
    expect(File.read(root.join("app/assets/builds/lean/site.css"))).to eq("/*! license */.btn{color:red}.kept{x:y}.show{z:1}")
    expect(report.summary).to match(/\Asite: .* KB → .* KB \(.* gzipped\), 3 of 6 rules removed\z/)
  end

  it "is stale until built, then when a view or the settings change" do
    expect(build).to be_stale
    build.run
    expect(build).not_to be_stale

    File.utime(Time.now + 5, Time.now + 5, root.join("app/views/home/index.html.erb"))
    expect(build).to be_stale
    build.run

    changed = Leancss::Configuration.new({ builds: { "site" => { css: %w[ a.css b.css ], safelist: %w[ other ] } } }, root: root).builds.first
    expect(changed).to be_stale
  end

  it "is stale when a Sass partial changes" do
    write("app/assets/stylesheets/_colors.scss", "$brand: #c00;")
    write("app/assets/stylesheets/site.scss", "@import 'colors';\n.btn { color: $brand; }")
    sass = Leancss::Configuration.new({ builds: { "site" => { css: %w[ site.scss ] } } }, root: root).builds.first
    sass.run
    expect(sass).not_to be_stale

    File.utime(Time.now + 5, Time.now + 5, root.join("app/assets/stylesheets/_colors.scss"))
    expect(sass).to be_stale
  end

  it "reports what it would remove, and suspects from class names built in code" do
    report = build.report
    expect(report.result.removed.keys).to contain_exactly("unused", "alert-danger", "alert-info")
    expect(report.suspects).to eq("alert-" => %w[ alert-danger alert-info ])
    expect(report.details).to include("alert-… in index.html.erb: alert-danger alert-info")
    expect(root.join("app/assets/builds/lean/site.css")).not_to exist
  end
end
