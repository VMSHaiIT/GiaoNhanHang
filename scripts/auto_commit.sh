#!/bin/bash

# Script tự động tạo commit message theo Conventional Commits (GiaoNhanHang)
# Sử dụng: ./scripts/auto_commit.sh [--dry-run] [--type TYPE] [--scope SCOPE] [--message MESSAGE]
#
# Script sẽ:
# 1. Phát hiện các file đã thay đổi
# 2. Phân loại thay đổi (feat, fix, docs, style, refactor, perf, test, chore, build, ci)
# 3. Tạo commit message: type(scope): description
# 4. Tạo commit (hoặc chỉ hiển thị nếu --dry-run)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
FORCE_TYPE=""
FORCE_SCOPE=""
CUSTOM_MESSAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --type)
            FORCE_TYPE="$2"
            shift 2
            ;;
        --scope)
            FORCE_SCOPE="$2"
            shift 2
            ;;
        --message)
            CUSTOM_MESSAGE="$2"
            shift 2
            ;;
        *)
            echo "❌ Tham số không hợp lệ: $1"
            echo "Sử dụng: $0 [--dry-run] [--type TYPE] [--scope SCOPE] [--message MESSAGE]"
            exit 1
            ;;
    esac
done

cd "$PROJECT_ROOT"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Không phải git repository"
    exit 1
fi

if [ -z "$(git status --porcelain)" ]; then
    echo "ℹ️  Không có thay đổi nào để commit"
    exit 0
fi

detect_commit_type() {
    local changed_files=$(git diff --cached --name-only 2>/dev/null || git diff --name-only 2>/dev/null)
    if [ -z "$changed_files" ]; then
        echo "chore"
        return
    fi
    if echo "$changed_files" | grep -qiE "(BREAKING|breaking)" > /dev/null; then
        echo "major"
        return
    fi
    local has_feat=false has_fix=false has_docs=false has_test=false
    local has_style=false has_refactor=false has_perf=false has_build=false has_ci=false
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        case "$file" in
            *_test.dart|*_test.py|*.test.ts|*.test.js|*.spec.ts|*.spec.js|**/test/**|**/tests/**) has_test=true ;;
            *.md|*.txt|**/docs/**|README*|CHANGELOG*|LICENSE*) has_docs=true ;;
            .github/**|.gitlab-ci.yml|**/ci/**) has_ci=true ;;
            **/build.gradle*|**/pubspec.yaml|**/package.json) has_build=true ;;
        esac
        echo "$file" | grep -qiE "(feature|feat|new|add)" && has_feat=true
        echo "$file" | grep -qiE "(fix|bug|error|issue)" && has_fix=true
        echo "$file" | grep -qiE "(refactor|restructure)" && has_refactor=true
        echo "$file" | grep -qiE "(style|format|lint)" && has_style=true
        echo "$file" | grep -qiE "(perf|performance|optimize)" && has_perf=true
    done <<< "$changed_files"
    local diff_content=$(git diff --cached 2>/dev/null || git diff 2>/dev/null)
    echo "$diff_content" | grep -qiE "^\+\s*(function|def|class|export\s+(const|function|class))" && has_feat=true
    echo "$diff_content" | grep -qiE "^\+\s*(fix|bug|error|exception|catch)" && has_fix=true
    echo "$diff_content" | grep -qiE "^\+\s*(refactor|extract|split|rename)" && has_refactor=true
    echo "$diff_content" | grep -qiE "^\+\s*(cache|optimize|performance)" && has_perf=true
    [ "$has_feat" = true ] && echo "feat" && return
    [ "$has_fix" = true ] && echo "fix" && return
    [ "$has_perf" = true ] && echo "perf" && return
    [ "$has_refactor" = true ] && echo "refactor" && return
    [ "$has_test" = true ] && echo "test" && return
    [ "$has_style" = true ] && echo "style" && return
    [ "$has_docs" = true ] && echo "docs" && return
    [ "$has_build" = true ] && echo "build" && return
    [ "$has_ci" = true ] && echo "ci" && return
    echo "chore"
}

detect_commit_scope() {
    local changed_files=$(git diff --cached --name-only 2>/dev/null || git diff --name-only 2>/dev/null)
    [ -z "$changed_files" ] && echo "" && return
    local first_file=$(echo "$changed_files" | head -n1)
    local scope=""
    if echo "$first_file" | grep -qiE "(screen|page|view)" > /dev/null; then
        scope=$(echo "$first_file" | sed -E 's|.*/(screens?|pages?|views?)/.*|\1|i' | tr '[:upper:]' '[:lower:]')
    elif echo "$first_file" | grep -qiE "(controller|service|provider)" > /dev/null; then
        scope=$(echo "$first_file" | sed -E 's|.*/(controllers?|services?|providers?)/.*|\1|i' | tr '[:upper:]' '[:lower:]')
    elif echo "$first_file" | grep -qiE "(model|entity)" > /dev/null; then
        scope=$(echo "$first_file" | sed -E 's|.*/(models?|entities?)/.*|\1|i' | tr '[:upper:]' '[:lower:]')
    elif echo "$first_file" | grep -qiE "script" > /dev/null; then
        scope="scripts"
    else
        scope=$(dirname "$first_file" | sed 's|.*/||' | tr '[:upper:]' '[:lower:]')
    fi
    scope=$(echo "$scope" | sed 's/[^a-z]//g')
    [ -z "$scope" ] || [ ${#scope} -gt 20 ] && scope=$(basename "$first_file" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z]//g')
    echo "$scope"
}

generate_commit_message() {
    local commit_type="$1"
    local scope="$2"
    local changed_files=$(git diff --cached --name-only 2>/dev/null || git diff --name-only 2>/dev/null)
    [ -n "$CUSTOM_MESSAGE" ] && echo "$CUSTOM_MESSAGE" && return
    local file_count=$(echo "$changed_files" | wc -l | tr -d ' ')
    local main_file=$(echo "$changed_files" | head -n1)
    local main_file_name=$(basename "$main_file" | sed 's/\.[^.]*$//')
    case "$commit_type" in
        feat) echo "thêm tính năng ${main_file_name}" ;;
        fix) echo "sửa lỗi ${main_file_name}" ;;
        docs) echo "cập nhật tài liệu" ;;
        style) echo "chỉnh sửa format code" ;;
        refactor) echo "refactor ${main_file_name}" ;;
        perf) echo "tối ưu performance" ;;
        test) echo "thêm/cập nhật test" ;;
        build) echo "cập nhật build config" ;;
        ci) echo "cập nhật CI/CD" ;;
        chore)
            [ "$file_count" -eq 1 ] && echo "cập nhật ${main_file_name}" || echo "cập nhật ${file_count} files"
            ;;
        *) echo "cập nhật code" ;;
    esac
}

echo "🔍 Đang phân tích thay đổi..."
[ -n "$FORCE_TYPE" ] && COMMIT_TYPE="$FORCE_TYPE" || COMMIT_TYPE=$(detect_commit_type)
[ -n "$FORCE_SCOPE" ] && COMMIT_SCOPE="$FORCE_SCOPE" || COMMIT_SCOPE=$(detect_commit_scope)
COMMIT_MESSAGE=$(generate_commit_message "$COMMIT_TYPE" "$COMMIT_SCOPE")

if [ -n "$COMMIT_SCOPE" ]; then
    FULL_COMMIT_MESSAGE="${COMMIT_TYPE}(${COMMIT_SCOPE}): ${COMMIT_MESSAGE}"
else
    FULL_COMMIT_MESSAGE="${COMMIT_TYPE}: ${COMMIT_MESSAGE}"
fi

echo ""
echo "📝 Commit message:"
echo "   $FULL_COMMIT_MESSAGE"
echo ""
echo "📊 Files changed:"
git diff --cached --name-only 2>/dev/null || git diff --name-only 2>/dev/null | head -10
echo ""

if [ "$DRY_RUN" = false ]; then
    read -p "❓ Tạo commit với message này? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Đã hủy"
        exit 0
    fi
    if [ -z "$(git diff --cached --name-only)" ]; then
        echo "📦 Đang stage các file..."
        git add -A
    fi
    echo "💾 Đang tạo commit..."
    git commit -m "$FULL_COMMIT_MESSAGE"
    echo ""
    echo "✅ Đã tạo commit thành công!"
    echo "📝 Message: $FULL_COMMIT_MESSAGE"
else
    echo "🔍 DRY RUN - Không tạo commit thực sự"
fi
