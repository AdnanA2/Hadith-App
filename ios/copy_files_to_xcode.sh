#!/bin/bash

echo "🚀 Copying HadithApp Files to Xcode Project"
echo "============================================"

# Define source and destination directories
SOURCE_DIR="ios/HadithApp"
DEST_DIR="ios/HadithApp.xcodeproj/../HadithApp"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

echo ""
echo "📁 Copying Swift files..."

# List of essential Swift files to copy
SWIFT_FILES=(
    "Models.swift"
    "APIService.swift"
    "DailyHadithView.swift"
    "CollectionsView.swift"
    "HadithsView.swift"
    "ContentView.swift"
    "BaseService.swift"
    "ErrorHandler.swift"
    "Logger.swift"
    "Environment.swift"
    "UnifiedCacheManager.swift"
    "HadithAppApp.swift"
)

# Copy each Swift file
for file in "${SWIFT_FILES[@]}"; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$DEST_DIR/$file"
        echo "✅ Copied: $file"
    else
        echo "❌ Not found: $file"
    fi
done

echo ""
echo "📄 Copying Info.plist..."
if [ -f "$SOURCE_DIR/Info.plist" ]; then
    cp "$SOURCE_DIR/Info.plist" "$DEST_DIR/Info.plist"
    echo "✅ Copied: Info.plist"
else
    echo "❌ Not found: Info.plist"
fi

echo ""
echo "🎯 Next Steps in Xcode:"
echo "======================="
echo "1. In Xcode, right-click on your project"
echo "2. Choose 'Add Files to HadithApp'"
echo "3. Navigate to: ios/HadithApp/"
echo "4. Select all the .swift files"
echo "5. Make sure 'Add to target: HadithApp' is checked"
echo "6. Click 'Add'"
echo ""
echo "7. Replace Info.plist content with the copied version"
echo ""
echo "8. Build and Run (⌘+R)"

echo ""
echo "✅ Backend Status:"
if curl -s http://localhost:8000/health > /dev/null; then
    echo "   ✅ Backend server is running on localhost:8000"
else
    echo "   ❌ Backend server is not running"
fi

echo ""
echo "📱 Expected Result:"
echo "- App launches in iOS Simulator"
echo "- Daily Tab shows today's hadith"
echo "- Collections Tab shows Riyad us-Saliheen"
echo "- All Hadiths Tab shows 3 sample hadiths"
echo "- Pull-to-refresh works"
echo "- No network errors"
