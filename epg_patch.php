<?php
/**
 * XUI One — EPG Cache Patch
 *
 * Problem: When an admin assigns an EPG channel to a stream in the XUI One panel,
 * the per-stream cache file (content/epg/stream_<id>) is NOT generated immediately.
 * It only gets created during the nightly EPG cron (0 0 * * *), so the stream shows
 * "no EPG" for up to 24 hours after assignment.
 *
 * Fix: This script runs every minute (via root crontab) and generates the cache file
 * instantly for any stream that has channel_id + epg_id assigned but no cache file yet.
 *
 * Install:
 *   1. Copy this file to /home/xui/crons/epg_patch.php
 *   2. Add to root crontab (root needed for unix_socket MySQL auth):
 *      chattr -i /var/spool/cron/crontabs/root
 *      (crontab -l 2>/dev/null; echo "* * * * * /home/xui/bin/php/bin/php /home/xui/crons/epg_patch.php > /dev/null 2>&1") | crontab -
 *      chattr +i /var/spool/cron/crontabs/root
 *
 * Result: After assigning EPG to a stream, it appears green within 1 minute.
 */

set_time_limit(60);

$db = new mysqli(null, "root", "", "xui", null, "/run/mysqld/mysqld.sock");
if ($db->connect_error) exit(1);

$EPG_PATH = "/home/xui/content/epg/";

$result = $db->query("SELECT id, epg_id, channel_id FROM streams WHERE type = 1 AND epg_id IS NOT NULL AND channel_id IS NOT NULL AND channel_id != \"\"");
if (!$result) exit(1);

// Buffer all rows first to avoid cursor conflict on same connection
$streams = $result->fetch_all(MYSQLI_ASSOC);
$result->free();

foreach ($streams as $stream) {
    if (file_exists($EPG_PATH . "stream_" . $stream["id"])) continue;

    $epgid = (int)$stream["epg_id"];
    $chid  = $db->real_escape_string($stream["channel_id"]);

    $r = $db->query("SELECT * FROM epg_data WHERE epg_id = {$epgid} AND channel_id = \"{$chid}\" ORDER BY start ASC");
    if (!$r) continue;

    $rows = $r->fetch_all(MYSQLI_ASSOC);
    $r->free();

    if (empty($rows)) continue;

    file_put_contents($EPG_PATH . "stream_" . $stream["id"], igbinary_serialize($rows));
}

$db->close();
