#\!/bin/bash

# Method 1: Add individual testers
echo "Adding individual testers to TestFlight..."

# Add single tester
fastlane pilot add \
  -u proud@me.com \
  --email "tester@example.com" \
  --first_name "Test" \
  --last_name "User"

# Method 2: Add multiple testers from CSV file
echo "Creating testers.csv file..."
cat > testers.csv << 'CSV'
First Name,Last Name,Email
John,Doe,john@example.com
Jane,Smith,jane@example.com
Test,User,test@example.com
CSV

# Import from CSV
fastlane pilot import \
  -c testers.csv

# Method 3: Quick add multiple emails in one command
fastlane run testflight_add_beta_testers \
  beta_app_feedback_email:"feedback@nuri.com" \
  beta_app_description:"Nuri Bitcoin Wallet Beta" \
  emails:"email1@example.com,email2@example.com,email3@example.com"

