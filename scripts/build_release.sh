#!/bin/bash

# Script build release Flutter app và .NET backend - GiaoNhanHang
# Tự động tăng version trước khi build (trừ khi dùng --no-increment)
#
# Sử dụng: ./scripts/build_release.sh [platform] [increment_type] [--no-increment]
# Platform: apk | appbundle | ios | web | windows | macos | linux | backend | frontend | all
#   all (mặc định) = backend + web + apk
#   frontend = web + apk
#   backend = chỉ .NET API
# Increment type: major | minor | patch | build | auto (mặc định: auto)
# --no-increment: Chỉ build, không tăng version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_APP_DIR="$PROJECT_ROOT/app"
BACKEND_DIR="$PROJECT_ROOT/backend/GiaoNhanHangApi"

SKIP_VERSION_INCREMENT=false
PLATFORM=""
INCREMENT_TYPE="auto"

for arg in "$@"; do
    case "$arg" in
        --no-increment|--skip-version)
            SKIP_VERSION_INCREMENT=true
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

# Thiết lập Android SDK (cần cho build apk/appbundle)
setup_android_sdk() {
    if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
        export ANDROID_SDK_ROOT="$ANDROID_HOME"
        echo "✅ Sử dụng Android SDK: $ANDROID_HOME"
        return 0
    fi
    if [ -n "$ANDROID_SDK_ROOT" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
        export ANDROID_HOME="$ANDROID_SDK_ROOT"
        echo "✅ Sử dụng Android SDK: $ANDROID_SDK_ROOT"
        return 0
    fi
    local possible_paths=(
        "$HOME/Library/Android/sdk"
        "$HOME/Android/Sdk"
        "$HOME/.android/sdk"
    )
    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ] && [ -d "$path/platform-tools" ]; then
            export ANDROID_HOME="$path"
            export ANDROID_SDK_ROOT="$path"
            echo "✅ Tìm thấy Android SDK: $path"
            return 0
        fi
    done
    local local_props="$FLUTTER_APP_DIR/android/local.properties"
    if [ -f "$local_props" ]; then
        local sdk_path=$(grep "sdk.dir" "$local_props" | cut -d'=' -f2 | tr -d '\r' | sed 's|^file://||' | sed "s|\\\\|/|g" | xargs)
        if [ -n "$sdk_path" ] && [ -d "$sdk_path" ] && [ -d "$sdk_path/platform-tools" ]; then
            export ANDROID_HOME="$sdk_path"
            export ANDROID_SDK_ROOT="$sdk_path"
            echo "✅ Android SDK từ local.properties: $sdk_path"
            return 0
        fi
    fi
    echo "❌ Không tìm thấy Android SDK. Cài Android Studio hoặc set ANDROID_HOME."
    return 1
}

clean_flutter_app() {
    echo "🧹 Cleaning Flutter app..."
    cd "$FLUTTER_APP_DIR"
    flutter clean
    echo "📦 Getting dependencies..."
    flutter pub get
    echo ""
}

build_web() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Build Flutter Web"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cd "$FLUTTER_APP_DIR"
    flutter build web --release
    echo "✅ Web: build/web"
}

build_apk() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Build Flutter APK"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cd "$FLUTTER_APP_DIR"
    if ! setup_android_sdk; then
        exit 1
    fi
    flutter build apk --release
    echo "✅ APK: build/app/outputs/flutter-apk/app-release.apk"
}

build_appbundle() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Build App Bundle (AAB)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cd "$FLUTTER_APP_DIR"
    if ! setup_android_sdk; then
        exit 1
    fi
    flutter build appbundle --release
    echo "✅ AAB: build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Build iOS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cd "$FLUTTER_APP_DIR"
    flutter build ios --release
    echo "✅ iOS build xong"
}

# Hàm build .NET backend
build_backend() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Build .NET Backend"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cd "$BACKEND_DIR"

    if [ -d "./publish" ]; then
        echo "🗑️  Xóa thư mục publish cũ..."
        rm -rf ./publish
    fi

    echo "🔨 Building .NET API..."
    dotnet build -c Release
    echo "📦 Publishing .NET API..."
    dotnet publish -c Release -o ./publish

    if [ -f "web.config" ]; then
        cp web.config ./publish/web.config
        echo "✅ web.config đã copy vào publish"
    fi
    echo "✅ Backend đã publish tại: backend/GiaoNhanHangApi/publish"
}

echo "🚀 Build release GiaoNhanHang"
echo "📦 Platform: $PLATFORM"
if [ "$SKIP_VERSION_INCREMENT" = true ]; then
    echo "⏭️  Bỏ qua tăng version"
else
    echo "🔢 Increment: $INCREMENT_TYPE"
fi
echo ""

if [ "$SKIP_VERSION_INCREMENT" = false ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Bước 1: Tăng version"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    "$SCRIPT_DIR/increment_version.sh" "$INCREMENT_TYPE"
    echo ""
fi

# frontend: chỉ web + apk
if [[ "$PLATFORM" == "frontend" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Bước 2: Clean Flutter & Build frontend"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    clean_flutter_app
    build_web
    build_apk
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Build release hoàn tất!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

# backend: chỉ .NET
if [[ "$PLATFORM" == "backend" ]]; then
    build_backend
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Build release hoàn tất!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

# all: backend + web + apk
if [[ "$PLATFORM" == "all" ]]; then
    build_backend
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Bước 2: Clean Flutter & Build frontend"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    clean_flutter_app
    build_web
    build_apk
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Build release hoàn tất!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

# Platform đơn lẻ: apk | appbundle | ios | web | windows | macos | linux
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Bước 2: Clean & Build ($PLATFORM)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
clean_flutter_app

case "$PLATFORM" in
    apk)
        build_apk
        ;;
    appbundle|aab)
        build_appbundle
        ;;
    ios)
        build_ios
        ;;
    web)
        build_web
        ;;
    windows)
        cd "$FLUTTER_APP_DIR"
        flutter build windows --release
        echo "✅ Windows: build/windows"
        ;;
    macos)
        cd "$FLUTTER_APP_DIR"
        flutter build macos --release
        echo "✅ macOS: build/macos"
        ;;
    linux)
        cd "$FLUTTER_APP_DIR"
        flutter build linux --release
        echo "✅ Linux: build/linux"
        ;;
    *)
        echo "❌ Platform không hợp lệ: $PLATFORM"
        echo "   Dùng: apk | appbundle | ios | web | windows | macos | linux | backend | frontend | all"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Build release hoàn tất!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
