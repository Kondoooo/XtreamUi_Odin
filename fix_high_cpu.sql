-- ============================================================
-- FIX: CPU alta en MySQL por full table scans en odin_blocker
-- Fecha: 2026-05-13
-- Afecta: XtreamUI / Xtream Codes con módulo Odin activado
-- ============================================================

-- PROBLEMA:
-- La tabla odin_blocker no tenía índice en la columna `ip`.
-- XtreamCodes consulta esta tabla en cada conexión entrante:
--
--   SELECT COUNT(`id`), MAX(`timestamp`)
--   FROM `odin_blocker`
--   WHERE `ip` = '...' AND `timestamp` > ...
--
-- Sin índice, MySQL hace full table scan de millones de filas
-- por cada query, saturando la CPU con tráfico normal.

-- SOLUCIÓN: índice compuesto (ip, timestamp)
-- Cubre exactamente el WHERE que ejecuta Odin.

USE xtream_iptvpro;

CREATE INDEX idx_odin_blocker_ip_ts ON odin_blocker (ip, timestamp);

-- OPCIONAL: limpiar registros viejos para mantener la tabla liviana
-- (ajustar el intervalo según necesidad, ej. 7 días)
-- DELETE FROM odin_blocker WHERE timestamp < UNIX_TIMESTAMP(NOW() - INTERVAL 7 DAY);
