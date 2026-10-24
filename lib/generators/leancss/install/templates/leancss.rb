# leancss makes this app's CSS small: each build joins the stylesheets a layout
# needs, removes the rules for classes the views never use, and minifies the
# rest into app/assets/builds/lean/<name>.css. Link one in a layout with
#
#   <%%= stylesheet_link_tag "lean/public" %>
#
# Files rebuild on the next page request in development, at boot in test, and
# during assets:precompile in production. `bin/rails leancss:report` shows what
# trimming removes.
#
# Without builds, every .css and .scss file in app/assets/stylesheets whose name
# doesn't start with _ is built under the same name, against all the views.
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
#
# Rails.application.config.leancss.builds = {
#   "public" => {
#     css: %w[ https://cdn.example.com/framework/1.2.3/framework.css public.css ],
#     except: %w[ app/views/admin/**/* ]
#   },
#   "admin" => {
#     css: %w[ https://cdn.example.com/framework/1.2.3/admin.css admin.css ],
#     content: %w[ app/views/admin/**/* app/views/layouts/admin*/**/* app/helpers/**/*.rb ]
#   }
# }

# Class names to keep in every build.
# Rails.application.config.leancss.safelist = %w[ ]
