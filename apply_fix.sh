#!/bin/bash
# apply_fix.sh — Aplica el fix de CPU alta en odin_blocker
# Uso: bash apply_fix.sh
# Requiere acceso root a MySQL sin contraseña (socket local)

set -e

DB="xtream_iptvpro"

echo "[*] Verificando si el índice ya existe..."
EXISTS=$(mysql "$DB" -se "
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema='$DB'
  AND table_name='odin_blocker'
  AND index_name='idx_odin_blocker_ip_ts';
" 2>/dev/null)

if [ "$EXISTS" -gt "0" ]; then
  echo "[OK] El índice ya existe. No se requiere acción."
  exit 0
fi

echo "[*] Creando índice en odin_blocker(ip, timestamp)..."
echo "    Esto puede tardar 2-5 minutos según el tamaño de la tabla."

mysql "$DB" -e "CREATE INDEX idx_odin_blocker_ip_ts ON odin_blocker (ip, timestamp);"

echo "[OK] Índice creado correctamente."
echo ""
echo "[*] Estado actual de la carga del sistema:"
uptime
echo ""
echo "[*] Threads MySQL activos:"
mysql -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('Threads_running','Threads_connected');"
