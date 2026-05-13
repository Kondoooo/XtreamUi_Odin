# XtreamUI Odin — Fix: CPU alta en MySQL

## Problema

En servidores con **XtreamUI / Xtream Codes** y el módulo **Odin** activado, MySQL puede dispararse a **1000-1500% de CPU** causando load averages de 20-30 incluso en servidores de 32 núcleos.

### Causa raíz

La tabla `odin_blocker` almacena las IPs que el módulo Odin monitorea/bloquea. Con el tiempo acumula **millones de registros** (se han visto casos con 5+ millones de filas).

El problema es que **la tabla no tiene índice en la columna `ip`**, y XtreamCodes ejecuta esta query en cada conexión entrante:

```sql
SELECT COUNT(`id`) as `count`, MAX(`timestamp`) as `lastDate`
FROM `odin_blocker`
WHERE `ip` = '...' AND `timestamp` > ...
```

Sin índice, MySQL realiza un **full table scan completo** por cada consulta. Con tráfico normal esto se multiplica por decenas de queries simultáneos, saturando todos los núcleos de CPU.

### Síntomas

- `mysqld` consumiendo 1000%+ de CPU en `htop`/`top`
- Load average muy superior al número de núcleos
- Al correr `SHOW PROCESSLIST` se ven decenas de queries idénticos contra `odin_blocker` en estado `Sending data`
- `Handler_read_rnd_next` en valores de cientos de miles de millones

```
$ mysql -e "SHOW GLOBAL STATUS WHERE Variable_name='Handler_read_rnd_next';"
+----------------------+----------------+
| Variable_name        | Value          |
+----------------------+----------------+
| Handler_read_rnd_next| 396132926486   |  ← señal de full table scans masivos
+----------------------+----------------+
```

---

## Solución

Crear un índice compuesto en `(ip, timestamp)` que cubre exactamente el `WHERE` que usa Odin:

```sql
USE xtream_iptvpro;
CREATE INDEX idx_odin_blocker_ip_ts ON odin_blocker (ip, timestamp);
```

### Aplicar el fix

**Opción 1 — Script automático (recomendado):**

```bash
bash apply_fix.sh
```

El script verifica si el índice ya existe antes de crearlo.

**Opción 2 — Manual:**

```bash
mysql xtream_iptvpro -e "CREATE INDEX idx_odin_blocker_ip_ts ON odin_blocker (ip, timestamp);"
```

> La creación tarda **2-5 minutos** dependiendo del tamaño de la tabla. El servidor sigue funcionando durante el proceso.

---

## Resultados observados

| Métrica | Antes | Después |
|---|---|---|
| Load average (1 min) | 24.78 | 7.88 |
| CPU MySQL | ~1500% | ~5% |
| Threads MySQL activos | 28 | 6 |
| Queries contra odin_blocker | 20-30 simultáneos | 1-2 |

---

## Mantenimiento adicional recomendado

La tabla `odin_blocker` crece indefinidamente. Se recomienda purgar registros viejos periódicamente para mantener el índice eficiente:

```sql
-- Eliminar registros con más de 7 días de antigüedad
DELETE FROM odin_blocker
WHERE timestamp < UNIX_TIMESTAMP(NOW() - INTERVAL 7 DAY);
```

Puedes añadirlo como cron job:

```bash
# crontab -e
0 3 * * * mysql xtream_iptvpro -e "DELETE FROM odin_blocker WHERE timestamp < UNIX_TIMESTAMP(NOW() - INTERVAL 7 DAY);" 2>/dev/null
```

---

## Archivos

| Archivo | Descripción |
|---|---|
| `fix_high_cpu.sql` | Script SQL con el fix y comentarios explicativos |
| `apply_fix.sh` | Script bash que aplica el fix con verificación previa |
| `README.md` | Este documento |
