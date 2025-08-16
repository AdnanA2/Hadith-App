#!/bin/bash

echo "🚀 HadithApp Xcode Project Setup"
echo "=================================="

echo ""
echo "📋 Instructions:"
echo "1. Open Xcode"
echo "2. File → New → Project"
echo "3. iOS → App"
echo "4. Product Name: HadithApp"
echo "5. Interface: SwiftUI"
echo "6. Language: Swift"
echo "7. Save in: ios/ (overwrite existing)"
echo ""

echo "📁 Files to add to project:"
echo "- Models.swift"
echo "- APIService.swift"
echo "- DailyHadithView.swift"
echo "- CollectionsView.swift"
echo "- HadithsView.swift"
echo ""

echo "🔧 Info.plist configuration needed:"
echo "Add network security settings for localhost"
echo ""

echo "✅ Backend server status:"
if curl -s http://localhost:8000/health > /dev/null; then
    echo "   ✅ Backend server is running on localhost:8000"
else
    echo "   ❌ Backend server is not running"
    echo "   Run: source venv/bin/activate && python3 simple_server.py"
fi

echo ""
echo "🎯 Next steps:"
echo "1. Create new Xcode project as described above"
echo "2. Replace ContentView.swift with our version"
echo "3. Add all Swift files to project"
echo "4. Configure Info.plist for network security"
echo "5. Build and run (⌘+R)"
echo ""
echo "📱 Expected result:"
echo "- App launches in iOS Simulator"
echo "- Daily Tab shows today's hadith"
echo "- Collections Tab shows Riyad us-Saliheen"
echo "- All Hadiths Tab shows 3 sample hadiths"
echo "- Pull-to-refresh works"
echo "- No network errors"
