#!/usr/bin/env bash
# Rebuild the Flutter web release and refresh server/static/ so the next
# `git push` + server `git pull` ships the new app to the public demo URL.
#
#   ./scripts/build_web.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

flutter build web --release --no-tree-shake-icons

rm -rf server/static
mkdir -p server/static
cp -R build/web/. server/static/

echo
echo "Built. Static bundle:"
du -sh server/static
echo
echo "Next steps:"
echo "  git add server/static"
echo "  git commit -m 'Rebuild web demo'"
echo "  git push"
echo "  ssh root@47.237.79.175 'cd /root/flower_watering && git pull && \\"
echo "    /root/miniconda3/bin/supervisorctl -c /etc/supervisor/supervisord.conf restart flower_watering_service'"
