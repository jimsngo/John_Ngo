#!/bin/bash

# Script to push Hải's memorial website to GitHub
# This will update the GitHub repository with all changes

echo "🌟 Pushing Hải's Memorial Website to GitHub..."
echo "================================================"

# Add all changes
echo "📁 Adding all changes..."
git add .

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo "✅ No changes to commit. Repository is up to date."
    exit 0
fi

# Get current timestamp for commit message
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# Commit with meaningful message
echo "💾 Committing changes..."
git commit -m "Update memorial website for Hải - $timestamp

- Enhanced celebration of life theme with warm colors
- Added background photos for Joyful Spirit and Family First sections
- Updated content to focus on love, faith, and celebration
- Improved photo visibility and positioning"

# Push to GitHub
echo "🚀 Pushing to GitHub..."
git push origin master

if [ $? -eq 0 ]; then
    echo "✅ Successfully pushed to GitHub!"
    echo ""
    echo "🌐 Your memorial website is now updated at:"
    echo "   https://jimsngo.github.io/John_Ngo/"
    echo ""
    echo "💝 Hải's celebration of life website is live and ready to share with family!"
else
    echo "❌ Error pushing to GitHub. Please check your connection and try again."
    exit 1
fi