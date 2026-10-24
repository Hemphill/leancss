RSpec.describe Leancss::Configuration do
  def configuration(settings = {}, engine_roots: [])
    described_class.new({ builds: nil, content: nil, safelist: [] }.merge(settings), root: root, engine_roots: engine_roots)
  end

  it "builds every stylesheet not starting with _ when there are no builds" do
    write("app/assets/stylesheets/site.css", "")
    write("app/assets/stylesheets/admin.scss", "")
    write("app/assets/stylesheets/_partial.scss", "")
    builds = configuration.builds
    expect(builds.map(&:name)).to eq(%w[ admin site ])
    expect(builds.last.sources.map(&:entry)).to eq(%w[ site.css ])
    expect(builds.last.output_path).to eq(root.join("app/assets/builds/lean/site.css"))
  end

  it "reads the app's views, helpers and JavaScript, and engines' views" do
    view = write("app/views/home/index.html.erb", "")
    helper = write("app/helpers/application_helper.rb", "")
    js = write("app/javascript/application.js", "")
    write("app/models/user.rb", "")
    engine_view = write("engine/app/views/layouts/public.html.erb", "")
    write("app/assets/stylesheets/site.css", "")
    files = configuration(engine_roots: [ root.join("engine") ]).builds.first.content.files
    expect(files).to contain_exactly(view.to_s, helper.to_s, js.to_s, engine_view.to_s)
  end

  it "skips engine pages shown in the engine's own layout" do
    write("app/assets/stylesheets/site.css", "")
    kept = [
      write("engine/app/views/layouts/admin_cs3.html.erb", ""),
      write("engine/app/views/layouts/admin_cs3/_header.html.erb", ""),
      write("engine/app/views/action_text/contents/_content.html.erb", ""),
      write("engine/app/views/layouts/action_text/contents/_content.html.erb", "")
    ]
    write("engine/app/views/letter_opener_web/letters/index.html.erb", "")
    write("engine/app/views/layouts/letter_opener_web/letters.html.erb", "")
    write("engine/app/views/layouts/letter_opener_web/_styles.html.erb", "")
    files = configuration(engine_roots: [ root.join("engine") ]).builds.first.content.files
    expect(files).to match_array(kept.map(&:to_s))
  end

  it "uses each build's css, content, except and safelist" do
    admin_view = write("app/views/admin/users/index.html.erb", "")
    public_view = write("app/views/home/index.html.erb", "")
    builds = configuration({
      builds: {
        "public" => { css: %w[ a.css b.css ], except: %w[ app/views/admin/**/* ] },
        "admin" => { "css" => "a.css", "content" => %w[ app/views/admin/**/* ], "safelist" => %w[ x ], "trim" => false }
      },
      safelist: %w[ everywhere ]
    }).builds
    public, admin = builds
    expect(public.sources.map(&:entry)).to eq(%w[ a.css b.css ])
    expect(public.content.files).to eq([ public_view.to_s ])
    expect(admin.content.files).to eq([ admin_view.to_s ])
    expect(admin.safelist).to eq(%w[ everywhere x ])
    expect(admin).not_to be_trim
  end

  it "reads globs inside gems" do
    expect(configuration.files("gem:crass/lib/crass.rb")).to eq([ File.join(Gem.loaded_specs["crass"].full_gem_path, "lib/crass.rb") ])
    expect { configuration.files("gem:nope/x") }.to raise_error(Leancss::Error, /no gem named nope/)
  end

  it "rejects unknown options and builds without css" do
    expect { configuration({ builds: { "a" => { css: "a.css", contents: [] } } }).builds }.to raise_error(Leancss::Error, /unknown option :contents/)
    expect { configuration({ builds: { "a" => {} } }).builds }.to raise_error(Leancss::Error, /list its CSS files/)
  end
end
