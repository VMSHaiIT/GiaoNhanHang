#!/bin/bash

# Script build & publish tự động - GiaoNhanHang
# Thực hiện: tăng version → build release → copy artifacts vào thư mục release/ (sẵn sàng đăng store)
#
# Sử dụng:
#   ./scripts/build_publish.sh                    # all: tăng version (auto) + build apk + web + copy
#   ./scripts/build_publish.sh apk                 # chỉ apk
#   ./scripts/build_publish.sh appbundle           # chỉ app bundle (AAB) - cho Play Store
#   ./scripts/build_publish.sh apk patch           # tăng patch + build apk
#   ./scripts/build_publish.sh all --no-increment  # build không tăng version
#   ./scripts/build_publish.sh all --no-copy       # build nhưng không copy ra release/
#
# Tham số:
#   platform: apk | appbundle | web | all (mặc định: all)
#   increment_type: major | minor | patch | build | auto (mặc định: auto)
#   --no-increment: Bỏ qua tăng version
#   --no-copy: Không copy file build ra thư mục release/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_APP_DIR="$PROJECT_ROOT/app"
RELEASE_DIR="$PROJECT_ROOT/release"

SKIP_VERSION_INCREMENT=false
SKIP_COPY=false
PLATFORM=""
INCREMENT_TYPE="auto"

for arg in "$@"; do
    case "$arg" in
        --no-increment|--skip-version)
            SKIP_VERSION_INCREMENT=true
            ;;
        --no-copy)
            SKIP_COPY=true
            ;;
        *)
            if [ -z "$PLATFORM" ]; then
                PLATFORM="$arg"
            elif [ -z "$INCREMENT_TYPE" ] || [ "$INCREMENT_TYPE" = "auto" ]; then
                INCREMENT_TYPE="$arg"
            fi
            ;;
    esac
done

PLATFORM="${PLATFORM:-all}"
INCREMENT_TYPE="${INCREMENT_TYPE:-auto}"

# Lấy version hiện tại từ pubspec (sau khi build_release đã chạy increment nếu cần)
get_current_version() {
    local pubspec="$FLUTTER_APP_DIR/pubspec.yaml"
    if [ ! -f "$pubspec" ]; then
        echo "0.0.0+0"
        return
    fi
    grep "^version:" "$pubspec" | sed 's/version: //' | tr -d ' ' || echo "0.0.0+0"
}

# Copy artifacts vào release/<version>/
copy_to_release() {
    local version="$1"
    # Tên thư mục dùng + thay bằng - để tránh lỗi trên một số FS
    local version_safe=$(echo "$version" | tr '+' '-')
    local dest="$RELEASE_DIR/$version_safe"
    mkdir -p "$dest"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Copy artifacts → release/$version_safe"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local has_any=false

    # APK
    local apk_src="$FLUTTER_APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$apk_src" ]; then
        cp "$apk_src" "$dest/giao_nhan_hang-$version_safe.apk"
        echo "  ✅ giao_nhan_hang-$version_safe.apk"
        has_any=true
    fi

    # App Bundle (AAB)
    local aab_src="$FLUTTER_APP_DIR/build/app/outputs/bundle/release/app-release.aab"
    if [ -f "$aab_src" ]; then
        cp "$aab_src" "$dest/giao_nhan_hang-$version_safe.aab"
        echo "  ✅ giao_nhan_hang-$version_safe.aab"
        has_any=true
    fi

    # Web
    local web_src="$FLUTTER_APP_DIR/build/web"
    if [ -d "$web_src" ]; then
        cp -R "$web_src" "$dest/web"
        echo "  ✅ web/"
        has_any=true
    fi

    if [ "$has_any" = true ]; then
        echo ""
        echo "📁 Thư mục release: $dest"
        echo "   - APK/AAB: gửi lên store hoặc phân phối"
        echo "   - web/: deploy lên hosting tĩnh"
    else
        echo "  ⚠️  Không có artifact nào để copy (kiểm tra platform đã build)."
        rmdir "$dest" 2>/dev/null || true
    fi
}

echo "🚀 Build & Publish - GiaoNhanHang"
echo "   Platform: $PLATFORM"
echo "   Increment: $([ "$SKIP_VERSION_INCREMENT" = true ] && echo 'skip' || echo "$INCREMENT_TYPE")"
echo "   Copy to release/: $([ "$SKIP_COPY" = true ] && echo 'no' || echo 'yes')"
echo ""

# Bước 1: Build (có tăng version bên trong build_release.sh)
BUILD_ARGS=("$PLATFORM" "$INCREMENT_TYPE")
[ "$SKIP_VERSION_INCREMENT" = true ] && BUILD_ARGS+=("--no-increment")

"$SCRIPT_DIR/build_release.sh" "${BUILD_ARGS[@]}"

# Bước 2: Copy ra release/
if [ "$SKIP_COPY" = false ]; then
    VERSION=$(get_current_version)
    copy_to_release "$VERSION"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Build & Publish hoàn tất!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
