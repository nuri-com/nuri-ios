#!/bin/bash
cd /Users/eminmahrt/Developer/nuri-ios

# Remove the unused bdk-swift-local-backup folder
rm -rf bdk-swift-local-backup

# Stage the deletion
git add -A

# Commit the changes
git commit -m "chore: Remove unused bdk-swift-local-backup folder

- Remove local backup of BDK-Swift package that is not being used
- Project uses official BDK-Swift dependency from GitHub (v1.2.0)
- Cleaning up repository to avoid confusion

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to current branch
git push origin feature/secure-seed-keychain-storage

echo "Done! Removed bdk-swift-local-backup folder and pushed changes."