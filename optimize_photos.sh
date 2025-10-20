#!/bin/bash

# Script to optimize photos for web and GitHub
# This will compress the images to reduce file sizes while maintaining quality

echo "📸 Optimizing photos for Hải's memorial website..."
echo "=================================================="

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "⚠️  ImageMagick not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install imagemagick
    else
        echo "❌ Homebrew not found. Please install ImageMagick manually:"
        echo "   Visit: https://imagemagick.org/script/download.php#macosx"
        exit 1
    fi
fi

# Create optimized photos directory
mkdir -p Photos/optimized

echo "🔧 Compressing photos..."

# Process each photo
for photo in Photos/*.jpeg Photos/*.jpg; do
    if [ -f "$photo" ]; then
        filename=$(basename "$photo")
        echo "   Processing: $filename"
        
        # Compress and resize for web (max 1920px width, 85% quality)
        convert "$photo" \
            -resize 1920x1920\> \
            -quality 85 \
            -strip \
            "Photos/optimized/$filename"
            
        # Show size comparison
        original_size=$(du -h "$photo" | cut -f1)
        optimized_size=$(du -h "Photos/optimized/$filename" | cut -f1)
        echo "     Original: $original_size → Optimized: $optimized_size"
    fi
done

echo ""
echo "✅ Photo optimization complete!"
echo "📁 Optimized photos are in: Photos/optimized/"
echo ""
echo "📊 Size comparison:"
echo "   Original Photos folder: $(du -sh Photos/*.jpeg Photos/*.jpg 2>/dev/null | tail -1 | cut -f1)"
echo "   Optimized folder: $(du -sh Photos/optimized/ | cut -f1)"
echo ""
echo "🔄 Next steps:"
echo "1. Review the optimized photos"
echo "2. Replace original photos with optimized ones if quality looks good"
echo "3. Run the GitHub push script"