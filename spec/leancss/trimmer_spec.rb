RSpec.describe Leancss::Trimmer do
  def trim(css, words = %w[ used other ])
    described_class.new(words&.to_set).trim(css).css
  end

  it "keeps rules for used classes and drops the rest" do
    expect(trim(".used{color:red}.unused{color:blue}")).to eq(".used{color:red}")
  end

  it "keeps only the selectors in a list that are used" do
    expect(trim(".used, .unused > p {margin: 0}")).to eq(".used{margin:0}")
  end

  it "needs every class in a selector" do
    expect(trim(".used .unused{a:b}.used.other{c:d}")).to eq(".used.other{c:d}")
  end

  it "keeps element, attribute and universal selectors" do
    expect(trim("p{a:b}[type=\"file.x\"]{c:d}*{e:f}")).to eq("p{a:b}[type=\"file.x\"]{c:d}*{e:f}")
  end

  it "ignores classes inside :not() and :is()" do
    expect(trim(".used:not(.unused){a:b}:is(.unused, .nope) p{c:d}")).to eq(".used:not(.unused){a:b}:is(.unused, .nope) p{c:d}")
  end

  it "checks ids too" do
    expect(trim("#used{a:b}#missing{c:d}")).to eq("#used{a:b}")
  end

  it "reads escaped class names" do
    css = ".md\\:d-none{display:none}.w-1\\/2{width:50%}"
    expect(trim(css, %w[ md:d-none w-1/2 ])).to eq(css)
  end

  it "trims inside @media and @supports, dropping blocks left empty" do
    css = "@media (min-width: 576px) { .used{a:b} .unused{c:d} } @media print { .unused{e:f} } " \
          "@supports (display: grid) { @media screen { .used{g:h} } }"
    expect(trim(css)).to eq("@media (min-width: 576px){.used{a:b}}@supports (display: grid){@media screen{.used{g:h}}}")
  end

  it "keeps @keyframes, @font-face and custom properties" do
    css = "@keyframes spin { from { transform: rotate(0) } to { transform: rotate(360deg) } }" \
          "@font-face { font-family: X; src: url(x.woff2) }:root{--bs-blue: #0d6efd}"
    expect(trim(css)).to eq("@keyframes spin{from { transform: rotate(0) } to { transform: rotate(360deg) }}" \
                            "@font-face{font-family: X; src: url(x.woff2)}:root{--bs-blue:#0d6efd}")
  end

  it "keeps license comments and drops the others" do
    expect(trim("/*! Bootstrap (MIT) */\n/* notes */.used{a:b}")).to eq("/*! Bootstrap (MIT) */.used{a:b}")
  end

  it "keeps values exactly, with !important" do
    css = <<~CSS
      .used {
        content: "a  b";
        background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg'%3e%3c/svg%3e");
        color: red !important;
        box-shadow: 0 0 0 .25rem rgba(13, 110, 253, .25);
      }
    CSS
    expect(trim(css)).to eq(".used{content:\"a  b\";background-image:url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg'%3e%3c/svg%3e\");" \
                            "color:red!important;box-shadow:0 0 0 .25rem rgba(13, 110, 253, .25)}")
  end

  it "only minifies without words" do
    expect(trim(".a,\n.b {\n  color: red;\n}\n", nil)).to eq(".a,.b{color:red}")
  end

  it "counts what it removed" do
    result = described_class.new(Set["used"]).trim(".used{a:b}.gone{c:d}.gone p,.gone a{e:f}#map{g:h}")
    expect(result).to have_attributes(rules: 4, rules_removed: 3)
    expect(result.removed).to eq("gone" => 3, "#map" => 1)
  end
end
