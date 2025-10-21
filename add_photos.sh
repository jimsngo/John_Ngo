#!/bin/bash

# Memorial Slideshow Photo Management Script
# This script helps add new photos to Hai's memorial slideshow

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PHOTOS_DIR="./Photos"
SLIDESHOW_FILE="./slideshow.html"
BACKUP_DIR="./backup_slideshow"
MAX_FILE_SIZE_MB=5  # GitHub file size limit
QUALITY=85  # JPEG compression quality

echo -e "${BLUE}🎬 Memorial Slideshow Photo Manager${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to compress and resize image
compress_image() {
    local input_file="$1"
    local output_file="$2"
    
    print_status "Compressing: $(basename "$input_file")"
    
    # Get original size
    original_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)
    original_mb=$(echo "scale=2; $original_size / 1024 / 1024" | bc)
    
    # Compress with sips (macOS) or convert (ImageMagick)
    if command -v sips >/dev/null 2>&1; then
        # macOS sips command
        sips -Z 1920 -s format jpeg -s formatOptions $QUALITY "$input_file" --out "$output_file" >/dev/null 2>&1
    elif command -v convert >/dev/null 2>&1; then
        # ImageMagick (cross-platform)
        convert "$input_file" -resize 1920x1920\> -quality $QUALITY "$output_file"
    else
        print_warning "No image compression tool found. Copying original..."
        cp "$input_file" "$output_file"
    fi
    
    # Get compressed size
    if [ -f "$output_file" ]; then
        compressed_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
        compressed_mb=$(echo "scale=2; $compressed_size / 1024 / 1024" | bc)
        savings=$(echo "scale=1; ($original_size - $compressed_size) * 100 / $original_size" | bc)
        
        echo "    ${original_mb}MB → ${compressed_mb}MB (${savings}% reduction)"
        
        # Check if still too large
        if (( $(echo "$compressed_mb > $MAX_FILE_SIZE_MB" | bc -l) )); then
            print_warning "File still large (${compressed_mb}MB). Consider manual compression."
        fi
    fi
}

# Function to backup slideshow
backup_slideshow() {
    if [ -f "$SLIDESHOW_FILE" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$SLIDESHOW_FILE" "$BACKUP_DIR/slideshow_$(date +%Y%m%d_%H%M%S).html"
        print_status "Slideshow backed up"
    fi
}

# Function to add new slide to HTML
add_slide_to_html() {
    local image_file="$1"
    local caption="$2"
    local temp_file=$(mktemp)
    
    # Create the new slide HTML
    local new_slide="        <div class=\"slide\">
            <img src=\"Photos/$(basename "$image_file")\" alt=\"Family memory\">
            <div class=\"slide-caption\">$caption</div>
        </div>"
    
    # Find the last slide and insert before the controls
    awk -v new_slide="$new_slide" '
    /^        <div class="controls">/ {
        print new_slide
        print ""
        print $0
        next
    }
    { print }
    ' "$SLIDESHOW_FILE" > "$temp_file"
    
    mv "$temp_file" "$SLIDESHOW_FILE"
    print_status "Added slide to slideshow.html"
}

# Function to update slide count
update_slide_count() {
    local photo_count=$(find "$PHOTOS_DIR" -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" | wc -l | tr -d ' ')
    
    # Update the total slides count in JavaScript
    sed -i.bak "s/\(<span id=\"totalSlides\">\)[0-9]*\(<\/span>\)/\1$photo_count\2/" "$SLIDESHOW_FILE"
    rm "${SLIDESHOW_FILE}.bak" 2>/dev/null || true
    
    print_status "Updated slide count to $photo_count"
}

# Main menu
show_menu() {
    echo ""
    echo -e "${BLUE}Choose an option:${NC}"
    echo "1. Scan Photos folder for new photos (Recommended)"
    echo "2. Add new photos from another directory"
    echo "3. Add a single photo"
    echo "4. Add background music to slideshow"
    echo "5. List current photos"
    echo "6. View slideshow in browser"
    echo "7. Push changes to GitHub"
    echo "8. Exit"
    echo ""
}

# Function to scan Photos folder for new photos
scan_photos_folder() {
    echo ""
    echo -e "${BLUE}Scanning Photos folder for new images...${NC}"
    
    if [ ! -d "$PHOTOS_DIR" ]; then
        print_error "Photos directory not found: $PHOTOS_DIR"
        return 1
    fi
    
    # Backup slideshow
    backup_slideshow
    
    # Count existing slides in slideshow
    existing_count=$(grep -c '<div class="slide">' "$SLIDESHOW_FILE" 2>/dev/null || echo "0")
    added_count=0
    
    # Find image files in Photos directory that aren't in slideshow yet
    find "$PHOTOS_DIR" \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -type f | while read -r image_file; do
        if [ -f "$image_file" ]; then
            filename=$(basename "$image_file")
            
            # Check if this photo is already in the slideshow
            if grep -q "Photos/$filename" "$SLIDESHOW_FILE" 2>/dev/null; then
                print_warning "Already in slideshow: $filename"
                continue
            fi
            
            print_status "Found new photo: $filename"
            
            # Ask for caption
            echo -n "Enter caption for $filename (or press Enter for default): "
            read caption
            if [ -z "$caption" ]; then
                caption="A cherished memory of Hai with family and friends"
            fi
            
            add_slide_to_html "$image_file" "$caption"
            ((added_count++))
        fi
    done
    
    if [ $added_count -eq 0 ]; then
        print_warning "No new photos found in Photos folder"
    else
        update_slide_count
        print_status "Added $added_count new photos to slideshow!"
    fi
}

# Function to add photos from another directory  
add_photos_from_directory() {
    echo ""
    read -p "Enter the path to the directory containing photos: " source_dir
    
    if [ ! -d "$source_dir" ]; then
        print_error "Directory not found: $source_dir"
        return 1
    fi
    
    # Create Photos directory if it doesn't exist
    mkdir -p "$PHOTOS_DIR"
    
    # Backup slideshow
    backup_slideshow
    
    # Find image files
    find "$source_dir" \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -type f | while read -r image_file; do
        if [ -f "$image_file" ]; then
            filename=$(basename "$image_file")
            # Convert to .jpeg if needed
            if [[ "$filename" =~ \.(png|gif)$ ]]; then
                filename="${filename%.*}.jpeg"
            fi
            
            output_path="$PHOTOS_DIR/$filename"
            
            # Skip if already exists
            if [ -f "$output_path" ]; then
                print_warning "Skipping existing: $filename"
                continue
            fi
            
            # Compress and add
            compress_image "$image_file" "$output_path"
            
            # Ask for caption
            echo -n "Enter caption for $(basename "$image_file") (or press Enter for default): "
            read caption
            if [ -z "$caption" ]; then
                caption="A cherished memory of Hai with family and friends"
            fi
            
            add_slide_to_html "$output_path" "$caption"
        fi
    done
    
    update_slide_count
    print_status "Photo import complete!"
}

# Function to add single photo
add_single_photo() {
    echo ""
    read -p "Enter the path to the photo: " photo_path
    
    if [ ! -f "$photo_path" ]; then
        print_error "Photo not found: $photo_path"
        return 1
    fi
    
    mkdir -p "$PHOTOS_DIR"
    backup_slideshow
    
    filename=$(basename "$photo_path")
    if [[ "$filename" =~ \.(png|gif)$ ]]; then
        filename="${filename%.*}.jpeg"
    fi
    
    output_path="$PHOTOS_DIR/$filename"
    
    compress_image "$photo_path" "$output_path"
    
    echo -n "Enter caption for this photo: "
    read caption
    if [ -z "$caption" ]; then
        caption="A beautiful memory of Hai"
    fi
    
    add_slide_to_html "$output_path" "$caption"
    update_slide_count
    
    print_status "Photo added successfully!"
}

# Function to add background music
add_background_music() {
    echo ""
    echo -e "${BLUE}Adding Background Music to Slideshow${NC}"
    echo "This will add a music player to the slideshow."
    echo ""
    
    read -p "Enter the path to your music file (MP3, WAV, or OGG): " music_path
    
    if [ ! -f "$music_path" ]; then
        print_error "Music file not found: $music_path"
        return 1
    fi
    
    # Copy music file to project
    music_filename=$(basename "$music_path")
    cp "$music_path" "./$music_filename"
    
    backup_slideshow
    
    # Add music HTML and controls to slideshow
    temp_file=$(mktemp)
    
    # Add audio element and enhanced controls
    awk -v music_file="$music_filename" '
    /<div class="controls">/ {
        print "        <audio id=\"backgroundMusic\" loop>"
        print "            <source src=\"" music_file "\" type=\"audio/mpeg\">"
        print "            <source src=\"" music_file "\" type=\"audio/wav\">"
        print "            <source src=\"" music_file "\" type=\"audio/ogg\">"
        print "            Your browser does not support the audio element."
        print "        </audio>"
        print ""
        print "        <div class=\"music-controls\" style=\"position: absolute; top: 20px; right: 20px; z-index: 200;\">"
        print "            <button class=\"btn\" onclick=\"toggleMusic()\" id=\"musicBtn\" style=\"padding: 8px 16px; font-size: 0.9rem;\">🎵 Play Music</button>"
        print "        </div>"
        print ""
    }
    { print }
    ' "$SLIDESHOW_FILE" > "$temp_file"
    
    # Add music JavaScript functions
    awk '
    /window\.addEventListener\('"'"'orientationchange'"'"'/ {
        print "        // Music control functions"
        print "        let musicPlaying = false;"
        print "        const backgroundMusic = document.getElementById(\"backgroundMusic\");"
        print "        const musicBtn = document.getElementById(\"musicBtn\");"
        print ""
        print "        function toggleMusic() {"
        print "            if (musicPlaying) {"
        print "                backgroundMusic.pause();"
        print "                musicBtn.textContent = \"🎵 Play Music\";"
        print "                musicPlaying = false;"
        print "            } else {"
        print "                backgroundMusic.play().catch(e => {"
        print "                    console.log(\"Music play failed:\", e);"
        print "                    alert(\"Please interact with the page first to enable music.\");"
        print "                });"
        print "                musicBtn.textContent = \"🔇 Pause Music\";"
        print "                musicPlaying = true;"
        print "            }"
        print "        }"
        print ""
        print "        // Auto-start music (requires user interaction first)"
        print "        document.addEventListener(\"click\", function startMusicOnInteraction() {"
        print "            if (!musicPlaying && backgroundMusic) {"
        print "                backgroundMusic.play().catch(e => console.log(\"Auto-play prevented:\", e));"
        print "                musicPlaying = true;"
        print "                musicBtn.textContent = \"🔇 Pause Music\";"
        print "                document.removeEventListener(\"click\", startMusicOnInteraction);"
        print "            }"
        print "        }, { once: true });"
        print ""
    }
    { print }
    ' "$temp_file" > "$SLIDESHOW_FILE"
    
    rm "$temp_file"
    
    print_status "Background music added to slideshow!"
    print_warning "Note: Music will only play after user interaction due to browser policies."
}

# Function to list photos
list_photos() {
    echo ""
    echo -e "${BLUE}Current Photos in Slideshow:${NC}"
    echo "=========================="
    
    if [ -d "$PHOTOS_DIR" ]; then
        find "$PHOTOS_DIR" -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" | sort | while read -r photo; do
            if [ -f "$photo" ]; then
                filename=$(basename "$photo")
                size=$(stat -f%z "$photo" 2>/dev/null || stat -c%s "$photo" 2>/dev/null)
                size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
                echo "  📷 $filename (${size_mb}MB)"
            fi
        done
        
        total_count=$(find "$PHOTOS_DIR" -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" | wc -l | tr -d ' ')
        echo ""
        echo -e "${GREEN}Total: $total_count photos${NC}"
    else
        print_warning "No Photos directory found"
    fi
}

# Function to open slideshow in browser
view_slideshow() {
    if [ -f "$SLIDESHOW_FILE" ]; then
        print_status "Opening slideshow in browser..."
        if command -v open >/dev/null 2>&1; then
            open "$SLIDESHOW_FILE"
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$SLIDESHOW_FILE"
        else
            print_warning "Cannot open browser automatically. Open slideshow.html manually."
        fi
    else
        print_error "Slideshow file not found"
    fi
}

# Function to push to GitHub
push_to_github() {
    echo ""
    print_status "Preparing to push changes to GitHub..."
    
    if [ -f "./push_to_github.sh" ]; then
        chmod +x "./push_to_github.sh"
        ./push_to_github.sh
    else
        # Manual git commands
        git add .
        echo -n "Enter commit message (or press Enter for default): "
        read commit_msg
        if [ -z "$commit_msg" ]; then
            commit_msg="📷 Added new photos to memorial slideshow"
        fi
        
        git commit -m "$commit_msg"
        git push origin master
        
        print_status "Changes pushed to GitHub!"
    fi
}

# Check dependencies
check_dependencies() {
    if ! command -v bc >/dev/null 2>&1; then
        print_error "bc calculator not found. Please install bc: brew install bc"
        exit 1
    fi
}

# Main script execution
main() {
    check_dependencies
    
    while true; do
        show_menu
        read -p "Enter your choice (1-8): " choice
        
        case $choice in
            1) scan_photos_folder ;;
            2) add_photos_from_directory ;;
            3) add_single_photo ;;
            4) add_background_music ;;
            5) list_photos ;;
            6) view_slideshow ;;
            7) push_to_github ;;
            8) 
                echo ""
                print_status "Goodbye! 💙"
                exit 0
                ;;
            *) 
                print_error "Invalid choice. Please enter 1-8."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run the main function
main "$@"