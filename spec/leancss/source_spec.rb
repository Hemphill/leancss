RSpec.describe Leancss::Source do
  def source(entry)
    described_class.new(entry, stylesheets: root.join("app/assets/stylesheets"), cache: root.join("tmp/cache"), output_folder: "lean")
  end

  it "reads a stylesheet, pointing relative urls back at its folder" do
    write("app/assets/stylesheets/site.css", ".a{background:url(bg.png)}.b{background:url('/x.png')}.c{background:url(data:image/png;base64,AA==)}")
    expect(source("site.css").css).to eq(".a{background:url(../bg.png)}.b{background:url('/x.png')}.c{background:url(data:image/png;base64,AA==)}")
  end

  it "keeps urls right for stylesheets in subfolders" do
    write("app/assets/stylesheets/themes/dark.css", ".a{background:url(\"img/bg.png\")}")
    expect(source("themes/dark.css").css).to eq(".a{background:url(\"../themes/img/bg.png\")}")
  end

  it "compiles Sass" do
    write("app/assets/stylesheets/_colors.scss", "$brand: #c00;")
    write("app/assets/stylesheets/site.scss", "@use 'colors';\n.a { .b { color: colors.$brand; } }")
    expect(source("site.scss").css).to include(".a .b {\n  color: #c00;\n}")
  end

  it "compiles Sass that imports packages and the app's partials" do
    library = instance_double(Leancss::Package, path: root.join("tmp/cache/packages/library"), signature: "v1")
    expect(library).to receive(:fetch)
    write("tmp/cache/packages/library/scss/_buttons.scss", ".btn { color: $brand; }")
    write("app/assets/stylesheets/public/_variables.scss", "$brand: #c00;")
    write("app/assets/stylesheets/public.scss", "@import 'public/variables';\n@import 'library/scss/buttons';")
    public = described_class.new("public.scss", stylesheets: root.join("app/assets/stylesheets"), cache: root.join("tmp/cache"),
                                                output_folder: "lean", packages: [ library ])

    expect(public.css).to include(".btn {\n  color: #c00;\n}")
    expect(public.inputs.map { |path| path.relative_path_from(root).to_s }).to include("app/assets/stylesheets/public/_variables.scss")
    expect(public.signature).to eq([ "public.scss", [ "v1" ] ])
  end

  it "explains Sass errors" do
    write("app/assets/stylesheets/broken.scss", "@import 'missing';")
    expect { source("broken.scss").css }.to raise_error(Leancss::Error, /broken.scss: Can't find stylesheet to import.\n  broken.scss line 1: 'missing'/)
  end

  it "complains about a missing file" do
    expect { source("nope.css").css }.to raise_error(Leancss::Error, /nope.css isn't in/)
  end

  it "reads a URL from its cached download, making its urls absolute" do
    url = "https://cdn.example.com/framework/1.2.3/dist/css/site.css"
    cached = source(url).path
    cached.dirname.mkpath
    File.write(cached, ".a{background:url(../img/bg.png)}.b{src:url(\"/fonts/x.woff2\")}")
    expect(source(url).css).to eq(".a{background:url(https://cdn.example.com/framework/1.2.3/dist/img/bg.png)}" \
                                  ".b{src:url(\"/fonts/x.woff2\")}")
    expect(cached.basename.to_s).to end_with("-site.css")
  end
end
