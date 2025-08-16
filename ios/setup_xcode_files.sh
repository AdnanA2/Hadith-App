#!/bin/bash

echo "🚀 Setting up HadithApp Xcode Project Files"
echo "============================================"

# Check if we're in the right directory
if [ ! -d "ios/HadithApp" ]; then
    echo "❌ Error: ios/HadithApp directory not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo ""
echo "📁 Available Swift files in ios/HadithApp/:"
ls -la ios/HadithApp/*.swift

echo ""
echo "📋 Files to add to your Xcode project:"
echo "======================================"
echo "1. Models.swift"
echo "2. APIService.swift"
echo "3. DailyHadithView.swift"
echo "4. CollectionsView.swift"
echo "5. HadithsView.swift"
echo "6. ContentView.swift (replace existing)"
echo "7. BaseService.swift"
echo "8. ErrorHandler.swift"
echo "9. Logger.swift"
echo "10. Environment.swift"
echo "11. UnifiedCacheManager.swift"
echo "12. Info.plist (replace existing)"

echo ""
echo "🔧 Manual Steps Required in Xcode:"
echo "=================================="
echo "1. Right-click on your project in Xcode navigator"
echo "2. Choose 'Add Files to HadithApp'"
echo "3. Navigate to: ios/HadithApp/"
echo "4. Select all the .swift files listed above"
echo "5. Make sure 'Add to target: HadithApp' is checked"
echo "6. Click 'Add'"
echo ""
echo "7. Replace Info.plist:"
echo "   - Find Info.plist in your project"
echo "   - Right-click → 'Open As → Source Code'"
echo "   - Replace entire content with ios/HadithApp/Info.plist content"
echo ""
echo "8. Build and Run (⌘+R)"

echo ""
echo "✅ Backend Status:"
if curl -s http://localhost:8000/health > /dev/null; then
    echo "   ✅ Backend server is running on localhost:8000"
    echo "   ✅ API endpoints are ready"
else
    echo "   ❌ Backend server is not running"
    echo "   Run: source venv/bin/activate && python3 simple_server.py"
fi

echo ""
echo "🎯 Expected Result:"
echo "- App launches in iOS Simulator"
echo "- Daily Tab shows today's hadith"
echo "- Collections Tab shows Riyad us-Saliheen"
echo "- All Hadiths Tab shows 3 sample hadiths"
echo "- Pull-to-refresh works"
echo "- No network errors"
