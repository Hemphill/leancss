# CLAUDE.md

leancss is Greg's gem for making a Rails app's CSS small: it joins a layout's
stylesheets, removes rules for classes the app's views don't use, and minifies.
Pure Ruby (crass parses the CSS; sass-embedded compiles Sass when an app has
it), so apps need no Node.

- `lib/leancss/trimmer.rb`: the trimming itself; no Rails.
- `lib/leancss/content.rb`: the words in an app's files, and class names built
  in code.
- `lib/leancss/source.rb`: one css: entry (app file, Sass, or URL).
- `lib/leancss/package.rb`: a Sass library fetched from git at a tag.
- `lib/leancss/build.rb`: one output file, plus its Report.
- `lib/leancss/configuration.rb`: config.leancss → Builds, including defaults.
- `lib/leancss/railtie.rb`: config, development middleware, test boot build.
- `lib/tasks/leancss.rake`.
- `lib/generators/leancss/install`: the initializer, and public and admin
  `.scss` files modeled on Webstop's core-customizations (variables first,
  then Bootstrap and CS3, then the app's partials).

Run the specs with `./test` (Docker, ruby:4.0.7). It isn't called `rspec`
because `bundle exec rspec` inside the container would run the script instead
of RSpec.

## Decisions

- Pure Ruby, no Node, so apps build during `assets:precompile` (Heroku needs
  nothing extra) and never commit built files. PurgeCSS is the model for how
  trimming behaves; the existing Rails wrappers for it need Node and Sprockets.
- Greg's personal repo (github.com/Hemphill/leancss, public), though it's used
  with Webstop's Core Styles 3.
- Admin and public CSS are separate builds, each checked against its own views.
- The main user is the chat app (`../chat`), for people in Cuba on old phones
  with slow, expensive data: size matters, and so does never breaking a page.
  Its config is `config/initializers/leancss.rb`.

## Checking changes

1. `./test`.
2. In `../chat`, `bin/ci`. Chat installs leancss from GitHub, but in
   development Bundler uses this checkout (mounted at /leancss), so changes
   show up without pushing. Before chat deploys, push here and run
   `bundle update leancss` there.
3. For changes to what's trimmed, compare computed styles. A temporary system
   spec in chat visits pages with the CDN's CSS and with leancss's (switch the
   layouts' `_styles` partials with an env var), records about 40 computed
   styles for every element at 1200px and 390px wide, and diffs the two runs.
   The first version matched on all 13 pages checked. Wait about 2 seconds per
   page, since the Font Awesome kit styles icons after its script loads.
   Results so far: public 40.2 KB → 13.8 KB gzipped (with lite.css and
   chat.css), admin 39.9 KB → 12.8 KB.

## Things learned the hard way

- Write selectors from crass's raw tokens, not the selector's `:value`, which
  is unescaped: `.md\:d-none` would come out broken.
- Compact whitespace at the token level, never with a regex over the text, or
  spaces inside strings collapse.
- Engine views count by default (that's how styler's layouts are covered), but
  not pages an engine shows in its own layout (letter_opener_web, Solid Errors,
  Action Mailbox's conductor). Counting them kept chat's public CSS at 29.6 KB.
- Builds read files on disk, including git-ignored ones. Greg's styler checkout
  has `--ignore` folders that a production install won't have, so chat's
  config excludes them to keep development and production builds the same.
- The development middleware goes first in the stack, before Propshaft checks
  for changed files.
- Stamp files go in `tmp/cache/leancss`; in the builds folder Propshaft would
  publish them.
- CS3's GitHub tarball is 175 MB (docs, site, dist, images) for 100 KB of
  Sass, and the CDN has only its built CSS, so packages are fetched with a
  shallow, sparse git clone of the scss folder (about a second).
- Compiled with today's Dart Sass, the generated `public.scss` and
  `admin.scss` match CS3 v3.0.23's CDN files (built with Bootstrap 5.3.7) rule
  for rule, except that colors are written as `rgb(81.02%, …)` instead of
  `rgb(206.6, …)` (0.1 of a channel apart at most) and two empty rules.

## Not done yet

1. Switch chat to the generated Sass builds (its initializer still uses the
   CDN's CSS). In chat, the generated builds came to 13.6 KB (public, without
   lite.css and chat.css) and 12.6 KB (admin) gzipped.
2. Trim more:
   - read only the gem layouts an app uses (styler's views keep `modal` and
     `offcanvas`);
   - drop unused `@keyframes`;
   - drop unused custom properties (about 8 KB of chat's public build).
3. Pagy's pagination markup comes from Ruby code, not views, so its classes may
   need safelisting.
4. Check states that need clicking (open dropdowns, modals) in the comparison.
5. Specs for the Railtie (so far only tried by hand in chat).
6. Rebuild only the Sass builds that import a changed partial (Sass's
   `loaded_urls`), rather than all of them.
7. Later, Core Styles 4 on Bootstrap 6. Class names like `md:d-none` are
   already handled.
