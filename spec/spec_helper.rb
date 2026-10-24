require "leancss"
require "tmpdir"

module SpecFiles
  # A temporary app folder: write("app/views/a.html.erb", "...") then root.
  def root
    @root ||= Pathname(Dir.mktmpdir("leancss"))
  end

  def write(path, text)
    root.join(path).dirname.mkpath
    File.write(root.join(path), text)
    root.join(path)
  end
end

RSpec.configure do |config|
  config.include SpecFiles
  config.after { FileUtils.rm_rf(@root) if @root }
  config.disable_monkey_patching!
  config.order = :random
end
