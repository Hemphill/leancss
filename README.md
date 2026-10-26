# leancss

Makes a Rails app's CSS small. Each build joins the stylesheets a layout needs
(the app's own, Sass, or a framework's file from a CDN), removes the rules for
classes the app's views never use, and minifies the rest.

It's plain Ruby: no Node, no `package.json`. It works with Propshaft and import
maps, and builds during `assets:precompile`, so Heroku needs nothing extra.

For example, an app using Core Styles 3 (Bootstrap 5.3) went from 40 KB to
14 KB gzipped on its public pages, and rendered the same.

## Setup

```ruby
# Gemfile
gem "leancss", github: "Hemphill/leancss"
```

```sh
bin/rails generate leancss:install
bundle install
```

The generator sets an app up to compile Bootstrap and Core Styles 3 from Sass
with its own variables, as Webstop's core-customizations does for a retailer:

- `config/initializers/leancss.rb`: the Sass packages (Bootstrap and Core
  Styles 3, at a tag) and two builds, `public` and `admin`, each trimmed
  against its own views.
- `app/assets/stylesheets/public.scss`: Bootstrap's functions, then
  `public/_variables.scss` (Bootstrap's and Core Styles' variables, commented
  out with their defaults), then Bootstrap and Core Styles, then the app's own
  partials (`public/_layout.scss`, `_header`, `_typography`, `_footer`).
- `app/assets/stylesheets/admin.scss`: the same with Webstop's admin look (as
  in Core Styles' `webstop-admin.css`), `admin/_variables.scss` and
  `admin/_admin.scss`.
- the sass-embedded gem in the Gemfile, and `/app/assets/builds/lean` in
  `.gitignore`.

Link the builds in the layouts:

```erb
<%= stylesheet_link_tag "lean/public" %>
```

With no changes to the variables, the builds match Core Styles' released
`core-styles-defaults.css` and `webstop-admin.css` before trimming.

## Builds

Without any settings, every `.css` and `.scss` file in `app/assets/stylesheets`
whose name doesn't start with `_` becomes a build of the same name
(`app/assets/builds/lean/<name>.css`), checked against all the views.

To join files, or to keep admin and public CSS apart, list the builds:

```ruby
cs3 = "https://s3.grocerywebsite.com/core-repos/core-styles-3/v3.0.23/dist/css"

Rails.application.config.leancss.builds = {
  "public" => {
    css: [ "#{cs3}/core-styles-defaults.css", "lite.css" ],
    except: %w[ app/views/admin/**/* gem:styler/app/views/layouts/admin_cs3* ]
  },
  "admin" => {
    css: [ "#{cs3}/webstop-admin.css" ],
    content: %w[ app/views/admin/**/* app/views/layouts/_* app/helpers/**/*.rb gem:styler/app/views/layouts/admin_cs3* ]
  }
}
```

Each build takes:

| Option | |
|---|---|
| `css:` | Files in `app/assets/stylesheets` (`.css`, or `.scss`/`.sass` with the sass-embedded gem), or URLs. Joined in this order. |
| `content:` | Globs of the files whose class names count. Defaults to the app's `app/views`, `app/helpers`, `app/components` and `app/javascript`, plus engines' views and helpers. |
| `except:` | Globs to leave out of `content`. |
| `safelist:` | Class names to keep anyway. |
| `trim:` | `false` to only join and minify. |

A glob starting with `gem:NAME/` is inside that gem, like
`gem:styler/app/views/layouts/admin_cs3*`.

URLs are downloaded once and cached in `tmp/cache/leancss`, so use URLs with a
version in them. Their relative `url()`s are made absolute.

`config.leancss.safelist` keeps class names in every build.

## Sass packages

`.scss` files can `@import` the app's other stylesheets and Sass libraries
listed as packages:

```ruby
Rails.application.config.leancss.packages = {
  "bootstrap" => { git: "https://github.com/twbs/bootstrap.git", tag: "v5.3.8" },
  "core-styles-3" => { git: "https://github.com/webstop/core-styles-3.git", tag: "v3.0.25" }
}
```

Each is fetched from git at its tag (only its `scss` folder; `only:` names
other folders) into `tmp/cache/leancss/packages/<name>`, which is on Sass's
load path, so `@import "bootstrap/scss/functions"` works as it would from
`node_modules`. Fetching needs git (Bundler already does for GitHub gems), and
takes a second or two the first time; change the tag to upgrade. Deprecation
warnings from packages are hidden.

## When files are built

- **Development:** before each page request, any build whose sources, views or
  settings changed is rebuilt. A change to any `.scss` file in
  `app/assets/stylesheets` rebuilds the Sass builds.
- **Test:** stale builds are rebuilt when the app boots.
- **Production:** `assets:precompile` runs `leancss:build` first.

Set `config.leancss.auto_build = false` to only build with the rake task.

## Tasks

- `bin/rails leancss:build` builds every file (`BUILD=public` for one).
- `bin/rails leancss:report` shows what trimming removes, without writing
  anything: sizes, the classes removed most, and class names the app builds in
  code (`"alert-#{type}"`, `alert-<%= type %>`) that may need safelisting.
- `bin/rails leancss:clobber` removes the built files and downloads (also run
  by `assets:clobber`).

## How trimming decides

Every run of letters, digits, `_` and `-` in the content files counts as a
word, so a class is kept wherever its name appears: a class attribute, a
helper, a JavaScript string. A CSS selector is kept when every class and id it
needs is a word.

- Element, attribute and universal selectors are always kept.
- Classes inside `:not()`, `:is()`, `:where()` and `:has()` don't count, since
  a page can match those without using them.
- Rules left with no selectors are removed, and so are `@media` and `@supports`
  blocks left empty.
- `@keyframes`, `@font-face`, custom properties and `/*!` license comments are
  kept whole.
- The classes Bootstrap's JavaScript adds while a page runs (`show`, `fade`,
  `collapsing`, tooltip and popover classes, …) are always kept.
- Engine pages shown in the engine's own layout (like letter_opener_web or
  Solid Errors) don't count, since they don't use the app's CSS.

Class names built in code can't be seen. `leancss:report` lists the prefixes it
finds and the removed classes that start with them; add the ones the app uses to
`safelist:`.

## Development

```sh
./test               # runs the specs in Docker
./test spec/leancss/trimmer_spec.rb
```

Or with Ruby installed: `bundle install && bundle exec rspec`.

## License

MIT
