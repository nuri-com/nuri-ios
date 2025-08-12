# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated testing of the Nuri iOS app.

## Workflows

### 1. iOS Tests (`ios-tests.yml`)
- **Trigger**: Push to main/develop, PRs to main/develop
- **Purpose**: Comprehensive test suite with XCTest
- **Features**:
  - Runs all unit tests
  - Generates test results
  - Uploads artifacts on failure

### 2. Swift Testing (`swift-testing.yml`)
- **Trigger**: Push/PR with Swift file changes
- **Purpose**: Dedicated Swift Testing framework support
- **Features**:
  - Matrix testing (multiple Xcode/iOS versions)
  - Code coverage reporting
  - Codecov integration
  - PR comments with results
  - Uses M1 Mac runners for speed

### 3. PR Tests (`pr-tests.yml`)
- **Trigger**: Pull requests only
- **Purpose**: Fast feedback for PRs
- **Features**:
  - Quick test execution (15 min timeout)
  - Changed file detection
  - GitHub summary generation
  - Minimal artifact storage

## Status Badges

Add these to your README.md:

```markdown
[![iOS Tests](https://github.com/nuri-com/nuri-ios/actions/workflows/ios-tests.yml/badge.svg)](https://github.com/nuri-com/nuri-ios/actions/workflows/ios-tests.yml)
[![Swift Testing](https://github.com/nuri-com/nuri-ios/actions/workflows/swift-testing.yml/badge.svg)](https://github.com/nuri-com/nuri-ios/actions/workflows/swift-testing.yml)
[![PR Tests](https://github.com/nuri-com/nuri-ios/actions/workflows/pr-tests.yml/badge.svg)](https://github.com/nuri-com/nuri-ios/actions/workflows/pr-tests.yml)
```

## Configuration

### Required Secrets
None required for basic testing.

### Optional Secrets
- `CODECOV_TOKEN`: For Codecov integration (in `swift-testing.yml`)

### Customization

#### Change Xcode Version
Edit the `DEVELOPER_DIR` environment variable or the matrix configuration:
```yaml
env:
  DEVELOPER_DIR: /Applications/Xcode_15.2.app/Contents/Developer
```

#### Change iOS Simulator
Update the destination in the workflows:
```yaml
-destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.2'
```

#### Adjust Timeouts
Modify the `timeout-minutes` value:
```yaml
timeout-minutes: 30
```

## Troubleshooting

### Tests Not Running
1. Check that the scheme "Nuri" exists and is shared
2. Verify test targets are included in the scheme
3. Ensure Swift Testing is properly configured

### Simulator Issues
- The workflows automatically boot simulators
- Uses `xcrun simctl boot` with error handling

### Cache Issues
Clear caches by incrementing the cache key version:
```yaml
key: ${{ runner.os }}-spm-v2-${{ hashFiles('**/Package.resolved') }}
```

## Best Practices

1. **Use PR Tests for Quick Feedback**: The `pr-tests.yml` workflow is optimized for speed
2. **Matrix Testing for Releases**: The `swift-testing.yml` workflow tests multiple configurations
3. **Cache Dependencies**: All workflows use caching to speed up builds
4. **Fail Fast**: PR tests have shorter timeouts to provide quick feedback

## Local Testing

To run the same tests locally:

```bash
# Run all tests
xcodebuild test -scheme Nuri -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# Run with Swift Testing
swift test --enable-testing-library

# Run with xcpretty for better output
xcodebuild test -scheme Nuri -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' | xcpretty --test
```