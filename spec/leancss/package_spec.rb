require "open3"

RSpec.describe Leancss::Package do
  # A git repo with these files, tagged, to fetch from.
  def repo(files, tag:)
    dir = root.join("repo")
    files.each { |path, text| write("repo/#{path}", text) }
    git = ->(*args) { Open3.capture2e("git", "-C", dir.to_s, "-c", "user.name=t", "-c", "user.email=t@t", *args).last.success? or raise "git #{args.first} failed" }
    git.call("init", "--quiet") unless dir.join(".git").exist?
    git.call("add", ".")
    git.call("commit", "--quiet", "--allow-empty", "-m", tag)
    git.call("tag", tag)
    "file://#{dir}"
  end

  def package(url, tag, **options)
    described_class.new("lib", { git: url, tag: tag, **options }, dir: root.join("packages"))
  end

  it "fetches only the scss folder at the tag" do
    url = repo({ "scss/_lib.scss" => "$a: 1;", "docs/big.png" => "x" }, tag: "v1")
    lib = package(url, "v1")
    expect(lib).not_to be_fetched

    lib.fetch
    expect(lib).to be_fetched
    expect(lib.path.join("scss/_lib.scss").read).to eq("$a: 1;")
    expect(lib.path.join("docs")).not_to exist
    expect(lib.path.join(".git")).not_to exist
  end

  it "fetches again when the tag changes" do
    url = repo({ "scss/_lib.scss" => "$a: 1;" }, tag: "v1")
    package(url, "v1").fetch
    repo({ "scss/_lib.scss" => "$a: 2;" }, tag: "v2")

    expect(package(url, "v1")).to be_fetched
    newer = package(url, "v2")
    expect(newer).not_to be_fetched
    newer.fetch
    expect(newer.path.join("scss/_lib.scss").read).to eq("$a: 2;")
  end

  it "keeps the old copy when a fetch fails" do
    url = repo({ "scss/_lib.scss" => "$a: 1;" }, tag: "v1")
    package(url, "v1").fetch

    expect { package(url, "v9").fetch }.to raise_error(Leancss::Error, /couldn't fetch v9 from file:/)
    expect(package(url, "v1")).to be_fetched
    expect(root.join("packages").children.map { |path| path.basename.to_s }).to eq(%w[ lib ])
  end

  it "needs a repo and a tag, and knows its options" do
    expect { described_class.new("lib", { git: "x" }, dir: root) }.to raise_error(Leancss::Error, /give its git: repo and the tag:/)
    expect { described_class.new("lib", { git: "x", tag: "v1", branch: "main" }, dir: root) }.to raise_error(Leancss::Error, /unknown option :branch/)
  end
end
