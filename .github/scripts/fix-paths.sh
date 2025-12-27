#!/bin/bash
set -e

echo "🔧 Fixing paths for GitHub Pages..."
BASEHREF="${BASEHREF:-${BASE_HREF:-/archived-sites}}"
echo "BASE: ${BASEHREF}"

# Найти все HTML
HTML_FILES=$(find . -name "*.html" -type f)

for file in $HTML_FILES; do
  # href="/..."
  sed -i 's|href="/|href="'$BASEHREF'/|g' "$file"
  
  # src="/..."
  sed -i 's|src="/|src="'$BASEHREF'/|g' "$file"
  
  # url(/...)
  sed -i 's|url(/|url('$BASEHREF'/|g' "$file"
  
  # url('/...')
  sed -i "s|url('/|url('$BASEHREF/|g" "$file"
  
  # url(\"/...\")
  sed -i 's|url(\"/|url(\"'$BASEHREF'/|g' "$file"
done

echo "✅ Paths fixed!"
