RSpec.describe Leancss::Content do
  it "collects the words in the files" do
    view = write("app/views/a.html.erb", %(<div class="btn btn-primary <%= active_class %>">))
    js = write("app/javascript/b.js", %(el.classList.add("is-open"); el.className = "md:d-none w-1/2"))
    words = described_class.new([ view, js ]).words
    expect(words).to include("btn", "btn-primary", "active_class", "is-open", "md:d-none", "w-1/2")
  end

  it "finds class names built in code" do
    ruby = write("app/helpers/a.rb", %(tag.div(class: "alert alert-\#{type}")))
    erb = write("app/views/a.html.erb", %(<p class="badge text-bg-<%= color %>">))
    js = write("app/javascript/b.js", %(el.classList.add(`text-${color}`); el.className = "bg-" + color))
    expect(described_class.new([ ruby, erb, js ]).dynamic_prefixes.keys).to contain_exactly("alert-", "text-bg-", "text-", "bg-")
  end
end
