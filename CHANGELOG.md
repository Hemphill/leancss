# Changelog

## 0.1.0 (unreleased)

- Builds that join stylesheets (app files, Sass, or URLs), trim them to the
  classes the app's views use, and minify them into `app/assets/builds/lean`.
- Builds with no settings: every stylesheet not starting with `_`.
- Rebuilds stale files on page requests in development and at boot in test, and
  during `assets:precompile`.
- `leancss:build`, `leancss:report` and `leancss:clobber` tasks, and the
  `leancss:install` generator.
