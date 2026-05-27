#!/usr/bin/env bash
# ============================================================
# clean_wordpress.sh
# Strips WordPress/Elementor runtime dependencies from a
# statically-exported index.html while keeping all styles
# and visual/functional content intact.
# Usage: bash clean_wordpress.sh [input.html] [output.html]
#   Defaults: index.html → index.clean.html
# ============================================================
set -euo pipefail

INPUT="${1:-index.html}"
OUTPUT="${2:-index.clean.html}"

if [[ ! -f "$INPUT" ]]; then
  echo "ERROR: File not found: $INPUT" >&2; exit 1
fi

echo "→ Reading: $INPUT"
cp "$INPUT" "$OUTPUT"

# 1. Remove WordPress meta/feed/oEmbed link tags
perl -i -0pe '
  s{<link[^>]+type="application/rss\+xml"[^>]*>\n?}{}gi;
  s{<link[^>]+type="(application/json\+oembed|text/xml\+oembed)"[^>]*>\n?}{}gi;
  s{<link[^>]+rel="https://api\.w\.org/"[^>]*>\n?}{}gi;
  s{<link[^>]+href="[^"]*wp-json[^"]*"[^>]*>\n?}{}gi;
  s{<link[^>]+type="application/rsd\+xml"[^>]*>\n?}{}gi;
  s{<link[^>]+rel="(shortlink|canonical)"[^>]*>\n?}{}gi;
  s{<link[^>]+rel="alternate"[^>]+type="application/json"[^>]*>\n?}{}gi;
' "$OUTPUT"

# 2. Remove WordPress generator meta tag
perl -i -0pe 's{<meta[^>]+name="generator"[^>]*>\n?}{}gi;' "$OUTPUT"

# 3. Remove WP Emoji block
perl -i -0pe '
  s{<style[^>]+id="wp-emoji-styles-inline-css"[^>]*>.*?</style>\n?}{}gsi;
  s{<script[^>]+id="wp-emoji-settings"[^>]*>.*?</script>\n?}{}gsi;
  s{<script[^>]+type="module"[^>]*>\s*/\*!.*?wp-emoji-loader.*?</script>\n?}{}gsi;
' "$OUTPUT"

# 4. Remove wp-img-auto-sizes inline style
perl -i -0pe 's{<style[^>]+id="wp-img-auto-sizes-contain-inline-css"[^>]*>.*?</style>\n?}{}gsi;' "$OUTPUT"

# 5. Remove Speculation Rules script block
perl -i -0pe 's{<script[^>]+type="speculationrules"[^>]*>.*?</script>\n?}{}gsi;' "$OUTPUT"

# 6. Remove Elementor JS bundles
perl -i -0pe '
  s{<script[^>]+id="elementor-webpack-runtime-js"[^>]*></script>\n?}{}gi;
  s{<script[^>]+id="elementor-frontend-modules-js"[^>]*></script>\n?}{}gi;
  s{<script[^>]+id="elementor-frontend-js-before"[^>]*>.*?</script>\n?}{}gsi;
  s{<script[^>]+id="elementor-frontend-js"[^>]*></script>\n?}{}gi;
' "$OUTPUT"

# 7. Remove jQuery (only needed for Elementor JS)
perl -i -0pe '
  s{<script[^>]+id="jquery-core-js"[^>]*></script>\n?}{}gi;
  s{<script[^>]+id="jquery-migrate-js"[^>]*></script>\n?}{}gi;
  s{<script[^>]+id="jquery-ui-core-js"[^>]*></script>\n?}{}gi;
' "$OUTPUT"

# 8. Remove hello-biz theme CSS links (canvas template bypasses theme)
perl -i -0pe '
  s{<link[^>]+id="hello-biz-css"[^>]*>\n?}{}gi;
  s{<link[^>]+id="hello-biz-header-footer-css"[^>]*>\n?}{}gi;
' "$OUTPUT"

# 9. Strip Elementor-only data attributes (dead without JS)
perl -i -pe '
  s/ data-id="[^"]*"//g;
  s/ data-e-type="[^"]*"//g;
  s/ data-element_type="[^"]*"//g;
  s/ data-widget_type="[^"]*"//g;
  s/ data-settings="(?![^"]*video)[^"]*"//g;
' "$OUTPUT"

# 10. Inject video src directly into <video> tag
perl -i -0pe '
  if (/id="bgVideo"[^>]*data-settings="([^"]*)"/) {
    my $settings = $1;
    $settings =~ s/&quot;/"/g;
    $settings =~ s/\\\//\//g;
    if ($settings =~ /"background_video_link"\s*:\s*"([^"]+)"/) {
      my $src = $1;
      s{(<video[^>]*class="elementor-background-video-hosted"[^>]*)>}{$1 src="$src" type="video/mp4">};
    }
  }
' "$OUTPUT"

# 11. Remove elementor-invisible class (JS-only animation hook)
perl -i -pe 's/ elementor-invisible\b//g;' "$OUTPUT"

# 12. Remove LiteSpeed Cache comment
perl -i -pe 's{<!-- Page supported by LiteSpeed Cache[^>]*-->}{}g;' "$OUTPUT"

# 13. Remove Simple Custom CSS and JS plugin comment wrappers
perl -i -pe 's{<!-- (start|end) Simple Custom CSS and JS -->\n?}{}g;' "$OUTPUT"

# 14. Collapse excessive blank lines
perl -i -0pe 's/\n{3,}/\n\n/g;' "$OUTPUT"

# 15. Inline layout + video CSS that Elementor's frontend.min.css normally provides.
#     Elementor sets --display/--width/--min-height etc. as CSS custom properties;
#     frontend.min.css maps these to real CSS. Without it, the layout breaks.
#     Also replaces the hero row responsive sizing: text 45% + video 55% = 100vw.
perl -i -0pe '
  my $css = <<ENDCSS;
<style id="static-layout-fix">
.e-con {
  position: relative;
  display: var(--display, flex);
  flex-direction: var(--flex-direction, column);
  flex-wrap: var(--flex-wrap-mobile, wrap);
  align-items: var(--align-items, flex-start);
  gap: var(--gap, 0px);
  min-height: var(--min-height, auto);
  width: var(--width, 100%);
  max-width: var(--container-max-width, 100%);
  padding-top: var(--padding-top, 0px);
  padding-right: var(--padding-right, 0px);
  padding-bottom: var(--padding-bottom, 0px);
  padding-left: var(--padding-left, 0px);
  margin-top: var(--margin-top, 0px);
  margin-right: var(--margin-right, auto);
  margin-bottom: var(--margin-bottom, 0px);
  margin-left: var(--margin-left, auto);
  order: var(--order, 0);
  overflow: var(--overflow, visible);
  z-index: var(--z-index, auto);
  flex-grow: var(--flex-grow, 0);
  flex-shrink: var(--flex-shrink, 1);
  align-self: var(--align-self, auto);
}
.e-con-boxed > .e-con-inner {
  width: 100%;
  max-width: var(--content-width, var(--container-max-width, 100%));
  margin-left: auto; margin-right: auto;
  display: var(--display, flex);
  flex-direction: var(--flex-direction, column);
  gap: var(--gap, 0px);
  flex: 1;
}
.e-grid {
  display: grid;
  grid-template-columns: var(--e-con-grid-template-columns, 1fr);
  grid-template-rows: var(--e-con-grid-template-rows, auto);
  grid-auto-flow: var(--grid-auto-flow, row);
}
/* Hero row: text left 45% + video right 55%, together = 100vw x 100vh */
.elementor-element-54768fda { flex-direction: row; min-height: 100vh; align-items: stretch; }
\@media (min-width: 768px) {
  .elementor-element-b3dbfd8  { width: 45%; flex-shrink: 0; }
  .elementor-element-59102c52 { width: 55%; flex-shrink: 0; min-height: 100vh; }
}
/* Tablet: stack vertically, video moves above text at 50vh */
\@media (max-width: 1024px) and (min-width: 768px) {
  .elementor-element-54768fda { flex-direction: column; }
  .elementor-element-b3dbfd8  { width: 100%; }
  .elementor-element-59102c52 { width: 100vw; min-height: 50vh; order: -99999; }
}
/* Mobile: same stack, video 50vh above text */
\@media (max-width: 767px) {
  .elementor-element-54768fda { flex-direction: column; flex-wrap: wrap; }
  .elementor-element-b3dbfd8  { width: 100%; }
  .elementor-element-59102c52 { width: 100%; min-height: 50vh; order: -99999; }
}
/* Video fills its container */
.elementor-background-video-container {
  position: absolute; top: 0; left: 0;
  width: 100%; height: 100%;
  overflow: hidden; z-index: 0; pointer-events: none;
}
.elementor-background-video-hosted {
  position: absolute; top: 50%; left: 50%;
  transform: translate(-50%, -50%);
  min-width: 100%; min-height: 100%;
  width: auto; height: auto; object-fit: cover;
}
#bgVideo { position: relative; overflow: hidden; }
@media (max-width: 1024px) {
  .elementor-element-6380de1e { align-self: center; width: 100%; display: flex; justify-content: center; }
  .elementor-element-6380de1e .elementor-widget-container { display: flex; justify-content: center; width: 100%; }
  .elementor-element-6380de1e .elementor-button-wrapper { display: flex; justify-content: center; }
}
</style>
ENDCSS
  s{</head>}{$css</head>};
' "$OUTPUT"

# Report sizes
ORIG=$(wc -c < "$INPUT")
CLEAN=$(wc -c < "$OUTPUT")
SAVED=$(( ORIG - CLEAN ))
PCT=$(awk "BEGIN { printf \"%.1f\", ($SAVED/$ORIG)*100 }")
echo "✓ Done: $OUTPUT"
echo "  Original : $(numfmt --to=iec $ORIG 2>/dev/null || echo ${ORIG}B)"
echo "  Cleaned  : $(numfmt --to=iec $CLEAN 2>/dev/null || echo ${CLEAN}B)"
echo "  Saved    : $(numfmt --to=iec $SAVED 2>/dev/null || echo ${SAVED}B) (${PCT}%)"
