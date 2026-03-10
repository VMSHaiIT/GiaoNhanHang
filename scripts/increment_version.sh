#!/bin/bash

# Script tự động tăng version cho Flutter app (GiaoNhanHang)
# Sử dụng: ./scripts/increment_version.sh [major|minor|patch|build|auto]
# Mặc định: auto (tự động phát hiện từ git commits)
#
# QUY TẮC VERSIONING (SEMANTIC VERSIONING):
# - PATCH (0.0.X): Khi có fix → tăng PATCH, BUILD_NUMBER tăng (không reset)
# - MINOR (0.X.0): Khi có feat mới → tăng MINOR, reset PATCH, BUILD_NUMBER tăng (không reset)
# - MAJOR (X.0.0): Khi có breaking changes → tăng MAJOR, reset MINOR/PATCH, BUILD_NUMBER tăng (không reset)
# - BUILD: Chỉ tăng BUILD_NUMBER
#
# LƯU Ý: Build number LUÔN LUÔN tăng, không bao giờ reset về 0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_PUBSPEC="$PROJECT_ROOT/app/pubspec.yaml"

INCREMENT_TYPE="${1:-auto}"

# Hàm tự động phát hiện loại version từ git commits
detect_version_type() {
    if ! cd "$PROJECT_ROOT" 2>/dev/null; then
        echo "❌ Không thể chuyển đến thư mục project: $PROJECT_ROOT" >&2
        echo "build"
        return
    fi

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "⚠️  Không phải git repository, sử dụng build" >&2
        echo "build"
        return
    fi

    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [ -z "$LAST_TAG" ]; then
        COMMITS=$(git log --pretty=format:"%s" -50 HEAD 2>/dev/null || echo "")
        echo "📝 Phân tích tất cả commits (chưa có tag)" >&2
    else
        COMMITS=$(git log --pretty=format:"%s" "${LAST_TAG}..HEAD" 2>/dev/null || echo "")
        echo "📝 Phân tích commits từ tag: $LAST_TAG" >&2
    fi

    if [ -z "$COMMITS" ]; then
        echo "⚠️  Không có commit mới, sử dụng build" >&2
        echo "build"
        return
    fi

    COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
    echo "📊 Tìm thấy $COMMIT_COUNT commit(s)" >&2

    # BREAKING CHANGE → MAJOR
    if echo "$COMMITS" | grep -qiE "(BREAKING CHANGE|!|breaking:)" > /dev/null; then
        echo "🚨 Phát hiện BREAKING CHANGE → major version" >&2
        echo "major"
        return
    fi

    # feat: → MINOR
    FEAT_COUNT=$(echo "$COMMITS" | grep -ciE "^feat(\(.+\))?:" 2>/dev/null || echo "0")
    FEAT_COUNT=$(echo "$FEAT_COUNT" | tr -d '[:space:]' | sed 's/[^0-9]//g')
    if [ -z "$FEAT_COUNT" ] || ! [[ "$FEAT_COUNT" =~ ^[0-9]+$ ]]; then
        FEAT_COUNT=0
    fi
    if [ "$FEAT_COUNT" -gt 0 ] 2>/dev/null; then
        echo "✨ Phát hiện $FEAT_COUNT feature commit(s) → minor version" >&2
        echo "minor"
        return
    fi

    # fix: → PATCH
    FIX_COUNT=$(echo "$COMMITS" | grep -ciE "^fix(\(.+\))?:" 2>/dev/null || echo "0")
    FIX_COUNT=$(echo "$FIX_COUNT" | tr -d '[:space:]' | sed 's/[^0-9]//g')
    if [ -z "$FIX_COUNT" ] || ! [[ "$FIX_COUNT" =~ ^[0-9]+$ ]]; then
        FIX_COUNT=0
    fi
    if [ "$FIX_COUNT" -gt 0 ] 2>/dev/null; then
        echo "🐛 Phát hiện $FIX_COUNT fix commit(s) → patch version" >&2
        echo "patch"
        return
    fi

    # perf, refactor, ... → PATCH
    OTHER_COUNT=$(echo "$COMMITS" | grep -ciE "^(perf|refactor|style|docs|test|chore|build|ci)(\(.+\))?:" 2>/dev/null || echo "0")
    OTHER_COUNT=$(echo "$OTHER_COUNT" | tr -d '[:space:]' | sed 's/[^0-9]//g')
    if [ -z "$OTHER_COUNT" ] || ! [[ "$OTHER_COUNT" =~ ^[0-9]+$ ]]; then
        OTHER_COUNT=0
    fi
    if [ "$OTHER_COUNT" -gt 0 ] 2>/dev/null; then
        echo "🔧 Phát hiện $OTHER_COUNT commit(s) khác → patch version" >&2
        echo "patch"
        return
    fi

    echo "📦 Không phát hiện commit đặc biệt → build number" >&2
    echo "build"
}

if [ "$INCREMENT_TYPE" = "auto" ]; then
    DETECTED_TYPE=$(detect_version_type)
    INCREMENT_TYPE="$DETECTED_TYPE"
    echo "🔍 Tự động phát hiện loại version: $INCREMENT_TYPE"
    echo ""
fi

echo "🔢 Đang tăng version (type: $INCREMENT_TYPE)..."

# Hàm tăng version cho Flutter (pubspec.yaml)
increment_flutter_version() {
    if [ ! -f "$FLUTTER_PUBSPEC" ]; then
        echo "❌ Không tìm thấy file pubspec.yaml tại: $FLUTTER_PUBSPEC"
        exit 1
    fi

    CURRENT_VERSION=$(grep "^version:" "$FLUTTER_PUBSPEC" | sed 's/version: //' | tr -d ' ')

    if [ -z "$CURRENT_VERSION" ]; then
        echo "❌ Không tìm thấy version trong pubspec.yaml"
        exit 1
    fi

    if [[ "$CURRENT_VERSION" == *"+"* ]]; then
        VERSION_PART=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
        BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)
    else
        VERSION_PART="$CURRENT_VERSION"
        BUILD_NUMBER=0
    fi

    if [ -z "$BUILD_NUMBER" ] || ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
        BUILD_NUMBER=0
    fi

    MAJOR=$(echo "$VERSION_PART" | cut -d'.' -f1)
    MINOR=$(echo "$VERSION_PART" | cut -d'.' -f2)
    PATCH=$(echo "$VERSION_PART" | cut -d'.' -f3)

    if [ -z "$MAJOR" ] || ! [[ "$MAJOR" =~ ^[0-9]+$ ]]; then MAJOR=1; fi
    if [ -z "$MINOR" ] || ! [[ "$MINOR" =~ ^[0-9]+$ ]]; then MINOR=0; fi
    if [ -z "$PATCH" ] || ! [[ "$PATCH" =~ ^[0-9]+$ ]]; then PATCH=0; fi

    case "$INCREMENT_TYPE" in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            BUILD_NUMBER=$((BUILD_NUMBER + 1))
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            BUILD_NUMBER=$((BUILD_NUMBER + 1))
            ;;
        patch)
            PATCH=$((PATCH + 1))
            BUILD_NUMBER=$((BUILD_NUMBER + 1))
            ;;
        build)
            BUILD_NUMBER=$((BUILD_NUMBER + 1))
            ;;
        *)
            echo "❌ Loại tăng version không hợp lệ: $INCREMENT_TYPE"
            echo "Sử dụng: major, minor, patch, hoặc build"
            exit 1
            ;;
    esac

    NEW_VERSION="$MAJOR.$MINOR.$PATCH+$BUILD_NUMBER"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^version:.*/version: $NEW_VERSION/" "$FLUTTER_PUBSPEC"
    else
        sed -i "s/^version:.*/version: $NEW_VERSION/" "$FLUTTER_PUBSPEC"
    fi

    echo "✅ Flutter version: $CURRENT_VERSION → $NEW_VERSION"
    echo "$NEW_VERSION"
}

NEW_FLUTTER_VERSION=$(increment_flutter_version)

echo ""
echo "🎉 Đã tăng version thành công!"
echo "📱 Version: $NEW_FLUTTER_VERSION"
echo ""
