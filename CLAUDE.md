# CLAUDE.md

leancss is Greg's gem for making a Rails app's CSS small: it joins a layout's
stylesheets, removes rules for classes the app's views don't use, and minifies.
Pure Ruby (crass parses the CSS; sass-embedded compiles Sass when an app has
it), so apps need no Node.

- `lib/leancss/trimmer.rb`: the trimming itself; no Rails.
- `lib/leancss/content.rb`: the words in an app's files, and class names built
  in code.
- `lib/leancss/source.rb`: one css: entry (app file, Sass, or URL).
- `lib/leancss/build.rb`: one output file, plus its Report.
- `lib/leancss/configuration.rb`: config.leancss → Builds, including defaults.
- `lib/leancss/railtie.rb`: config, development middleware, test boot build.
- `lib/tasks/leancss.rake`, `lib/generators/leancss/install`.

Run the specs with `./test` (Docker, ruby:4.0.7). The chat app
(`../chat`) uses the gem from `../leancss`; check changes there with its
`bin/ci` and by comparing pages' computed styles with and without trimming.
