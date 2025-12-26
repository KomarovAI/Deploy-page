#!/bin/bash
# Fix absolute paths for GitHub Pages deployment
# This script rewrites absolute paths to relative paths for GitHub Pages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "${YELLOW}🔧 Starting path fixing for GitHub Pages...${NC}"

# Find all HTML files and fix absolute paths
echo "${YELLOW}📝 Processing HTML files...${NC}"
find . -type f -name "*.html" | while read file; do
  # Replace /wp-content/ with archived-sites subfolder paths
  if grep -q "/wp-content/" "$file"; then
    # For now, make paths relative by adding ../ pattern detection
    # This will be improved based on the actual domain structure
    sed -i 's|href="/|href="./|g' "$file" || true
    sed -i 's|src="/|src="./|g' "$file" || true
  fi
done

echo "${YELLOW}📝 Processing CSS files...${NC}"
find . -type f -name "*.css" | while read file; do
  # Fix URLs in CSS files
  sed -i 's|url(/|url(./|g' "$file" || true
done

echo "${YELLOW}📝 Processing JavaScript files...${NC}"
find . -type f -name "*.js" | while read file; do
  # Fix URLs in JS files (common patterns)
  sed -i 's|/wp-content/|./wp-content/|g' "$file" || true
  sed -i 's|"/[a-zA-Z]|"./&|g' "$file" || true
done

# Add base href tag to HTML files if not present
echo "${YELLOW}📝 Adding base href tags...${NC}"
find . -type f -name "*.html" | while read file; do
  # Check if base tag already exists
  if ! grep -q '<base href=' "$file"; then
    # Add base href after opening head tag
    sed -i '/<head>/a \    <base href="/archived-sites/" />' "$file" || true
  fi
done

echo "${GREEN}✅ Path fixing completed successfully${NC}"
