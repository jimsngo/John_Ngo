#!/bin/bash

# Super compress just the two photos we need for the website
echo "🎯 Super-compressing key photos for GitHub..."

# Create web folder
mkdir -p Photos/web

# Super compress the football photo (Joyful Spirit)
echo "🏈 Compressing football photo (IMG_1636.jpeg)..."
convert Photos/IMG_1636.jpeg \
    -resize 800x600\> \
    -quality 70 \
    -strip \
    Photos/web/IMG_1636.jpeg

# Super compress Logan's birthday photo (Family First)  
echo "👨‍👩‍👧‍👦 Compressing Logan's birthday photo (IMG_3080.jpeg)..."
convert Photos/IMG_3080.jpeg \
    -resize 800x600\> \
    -quality 70 \
    -strip \
    Photos/web/IMG_3080.jpeg

echo "✅ Super compression complete!"
echo "📊 Results:"
ls -lh Photos/web/
echo ""
echo "Total size: $(du -sh Photos/web/ | cut -f1)"