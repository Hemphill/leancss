# leancss makes this app's CSS small: each build compiles or joins the
# stylesheets a layout needs, removes the rules for classes the views never
# use, and minifies the rest into app/assets/builds/lean/<name>.css. Link one in
# a layout with
#
#   <%%= stylesheet_link_tag "lean/public" %>
#
# Files rebuild on the next page request in development, at boot in test, and
# during assets:precompile in production. `bin/rails leancss:report` shows what
# trimming removes.
#
# Each build takes:
#   css:      files from app/assets/stylesheets (.css, or .scss with the
#             sass-embedded gem), or URLs with a version in them
#   content:  globs of the files whose class names count; defaults to the
#             app's and engines' views, helpers, components and JavaScript.
#             "gem:NAME/..." is a path inside a gem.
#   except:   globs to leave out of content
#   safelist: class names to keep anyway, like ones built in code
#   trim:     false to only join and minify

# Sass libraries for the .scss files to @import, fetched from git (only their
# scss folders) into tmp/cache/leancss/packages. Change a tag to upgrade.
Rails.application.config.leancss.packages = {
  "bootstrap" => { git: "https://github.com/twbs/bootstrap.git", tag: "<%= bootstrap_tag %>" },
  "core-styles-3" => { git: "https://github.com/webstop/core-styles-3.git", tag: "<%= core_styles_tag %>" }
}

# The public and admin pages each get CSS trimmed against their own views.
Rails.application.config.leancss.builds = {
  "public" => {
    css: %w[ public.scss ],
    except: %w[
      app/views/admin/**/* app/views/layouts/admin* app/views/layouts/admin*/**/*
<% if styler? -%>
      gem:styler/app/views/layouts/admin_cs3* gem:styler/app/views/layouts/admin_cs3/**/*
<% end -%>
    ]
  },
  "admin" => {
    css: %w[ admin.scss ],
    content: %w[
      app/views/admin/**/* app/views/layouts/admin* app/views/layouts/admin*/**/*
      app/views/layouts/_* app/views/application/**/* app/helpers/**/*.rb
<% if styler? -%>
      gem:styler/app/views/layouts/admin_cs3* gem:styler/app/views/layouts/admin_cs3/**/*
      gem:styler/app/views/layouts/_* gem:styler/app/helpers/**/*.rb
<% end -%>
    ]
  }
}

# Class names to keep in every build.
# Rails.application.config.leancss.safelist = %w[ ]
