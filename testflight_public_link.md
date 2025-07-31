# TestFlight Public Links & Redeem Codes

## Option 1: Public TestFlight Link (Easiest\!)
- No email needed - anyone with the link can test
- Limited to 10,000 testers
- Link expires after 90 days

### To create via App Store Connect:
1. Go to App Store Connect → Your App → TestFlight
2. Click "External Testing" → "External Groups"
3. Select your group (or create one)
4. Click "Enable Public Link"
5. Share the link (looks like: https://testflight.apple.com/join/XXXXXXXX)

### To create via CLI:
```bash
# Enable public link for a group
fastlane run testflight_create_public_link \
  group_name:"External Testers" \
  username:"proud@me.com"
```

## Option 2: Redeem Codes
- Generate codes for specific events/users
- Each code can only be used once
- Good for controlled distribution

### Via App Store Connect:
1. TestFlight → External Groups → Your Group
2. Click "Redeem Codes"
3. Generate codes (up to 100 at a time)

## Option 3: Internal Testing (No Review Needed)
- Add up to 100 Apple IDs directly
- Instant access, no TestFlight review
- Must be team members

