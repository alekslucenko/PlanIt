#!/bin/bash

# 🔥 Firestore Index Deployment Script for PlanItApp
# This script deploys the required composite indexes for the parties functionality

echo "🔥 Deploying Firestore indexes for PlanItApp..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if firestore.indexes.json exists
if [ ! -f "firestore.indexes.json" ]; then
    echo "❌ firestore.indexes.json not found in current directory"
    exit 1
fi

# Deploy the indexes
echo "📤 Deploying Firestore indexes..."
firebase deploy --only firestore:indexes

if [ $? -eq 0 ]; then
    echo "✅ Firestore indexes deployed successfully!"
    echo ""
    echo "📋 Deployed indexes:"
    echo "   • parties collection: isPublic + status + startDate"
    echo "   • rsvps collection: userId + status + rsvpDate"
    echo "   • parties collection: hostId + status + startDate"
    echo ""
    echo "⏰ Note: Index deployment can take several minutes to complete."
    echo "   You can check the status in the Firebase Console."
else
    echo "❌ Failed to deploy Firestore indexes"
    exit 1
fi 