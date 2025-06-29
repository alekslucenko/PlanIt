#!/bin/bash

# 🔥 FIRESTORE INDEXES DEPLOYMENT SCRIPT
# Deploys all required indexes for PlanItApp business dashboard and real-time features
# Run this script to fix all the Firestore index errors

echo "🚀 Deploying Firestore Indexes for PlanItApp Business Dashboard..."
echo "📊 This will enable real-time analytics and fix all query errors"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "   npm install -g firebase-tools"
    echo "   firebase login"
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged into Firebase. Please run:"
    echo "   firebase login"
    exit 1
fi

# Show current project
PROJECT=$(firebase use --quiet)
if [ -z "$PROJECT" ]; then
    echo "❌ No Firebase project selected. Please run:"
    echo "   firebase use <your-project-id>"
    exit 1
fi

echo "📋 Current Firebase project: $PROJECT"
echo ""

# Deploy indexes
echo "🔧 Deploying Firestore indexes..."
echo "   This enables:"
echo "   ✅ Business dashboard real-time metrics"
echo "   ✅ Party analytics and revenue tracking"
echo "   ✅ RSVP and attendee management"
echo "   ✅ Event interaction tracking"
echo "   ✅ Collection group queries for tickets"
echo ""

firebase deploy --only firestore:indexes

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Firestore indexes deployed successfully!"
    echo ""
    echo "🎯 INDEXES DEPLOYED:"
    echo "   📈 parties (isPublic + status + startDate)"
    echo "   📈 parties (status + startDate)"  
    echo "   📈 parties (hostId + status + startDate)"
    echo "   📈 rsvps (userId + status + rsvpDate)"
    echo "   📈 rsvps (status + rsvpDate + __name__)"
    echo "   📈 eventInteractions (type + timestamp)"
    echo "   📈 ticketSales (purchaseDate - collection group)"
    echo "   📈 users (createdAt)"
    echo ""
    echo "⚡ Real-time features now enabled:"
    echo "   💰 Revenue tracking works instantly"
    echo "   👥 RSVP counters update live"
    echo "   🎉 Event analytics show real data"
    echo "   📊 Business dashboard fully functional"
    echo ""
    echo "🔄 Please restart your app to see the changes!"
else
    echo ""
    echo "❌ Index deployment failed!"
    echo "   Please check your Firebase project permissions"
    echo "   and ensure you have Firestore admin access"
    exit 1
fi 