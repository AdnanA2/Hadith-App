#!/bin/bash

echo "🏛️ HadithApp iOS Setup"
echo "======================"

# Check if we're in the right directory
if [ ! -d "HadithApp" ]; then
    echo "❌ Error: HadithApp directory not found"
    echo "Please run this script from the ios/ directory"
    exit 1
fi

echo "✅ Found HadithApp directory"

# Check if backend server is running
echo "🔍 Checking backend server..."
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ Backend server is running on localhost:8000"
else
    echo "❌ Backend server is not running"
    echo "Please start the backend server first:"
    echo "cd .. && python3 simple_server.py"
    exit 1
fi

echo ""
echo "📱 Opening Xcode..."
echo ""

# Create a simple Xcode workspace file
cat > HadithApp.xcworkspace/contents.xcworkspacedata << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:HadithApp">
   </FileRef>
</Workspace>
EOF

# Open Xcode with the project
open -a Xcode HadithApp.xcworkspace

echo "🎯 Instructions for Xcode:"
echo "1. In Xcode, go to File → New → Project"
echo "2. Choose iOS → App"
echo "3. Set Product Name: HadithApp"
echo "4. Choose Interface: SwiftUI"
echo "5. Language: Swift"
echo "6. Save in the current directory (ios/HadithApp/)"
echo ""
echo "7. Replace the default ContentView.swift with our version"
echo "8. Add the other Swift files to the project:"
echo "   - Models.swift"
echo "   - APIService.swift"
echo "   - DailyHadithView.swift"
echo "   - CollectionsView.swift"
echo "   - HadithsView.swift"
echo ""
echo "9. Update Info.plist with network security settings"
echo "10. Build and run (⌘+R)"
echo ""
echo "✅ The app should connect to the backend and display hadiths!"
