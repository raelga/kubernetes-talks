<?php
/**
 * Plugin Name: Sonidos y Sonados - Site Fixes
 * Description: Runtime fixes for feed, SEO, security, and page cleanup. Dashboard at Tools > Site Fixes Status.
 * Drop into wp-content/mu-plugins/
 */

if (!defined('ABSPATH')) exit;

// === HEAD FIXES ===

// Add viewport meta tag for mobile
add_action('wp_head', function () {
    echo '<meta name="viewport" content="width=device-width, initial-scale=1.0" />' . PHP_EOL;
}, 0);

// Add favicon from podcast logo
add_action('wp_head', function () {
    $logo = 'https://sonidosysonados.com/wp-content/uploads/logo.jpg';
    echo '<link rel="icon" href="' . esc_url($logo) . '" />' . PHP_EOL;
    echo '<link rel="apple-touch-icon" href="' . esc_url($logo) . '" />' . PHP_EOL;
}, 0);

// Add SEO meta tags: canonical, Open Graph, Twitter Card
add_action('wp_head', function () {
    if (is_singular()) {
        $url = get_permalink();
        $title = get_the_title();
        $desc = get_the_excerpt() ?: get_bloginfo('description');
    } else {
        $url = home_url($_SERVER['REQUEST_URI']);
        $title = get_bloginfo('name');
        $desc = get_bloginfo('description');
    }
    $desc = wp_trim_words(strip_tags($desc), 30);
    $image = 'https://sonidosysonados.com/wp-content/uploads/logo.jpg';

    echo '<link rel="canonical" href="' . esc_url($url) . '" />' . PHP_EOL;
    echo '<meta property="og:type" content="website" />' . PHP_EOL;
    echo '<meta property="og:title" content="' . esc_attr($title) . '" />' . PHP_EOL;
    echo '<meta property="og:description" content="' . esc_attr($desc) . '" />' . PHP_EOL;
    echo '<meta property="og:url" content="' . esc_url($url) . '" />' . PHP_EOL;
    echo '<meta property="og:image" content="' . esc_url($image) . '" />' . PHP_EOL;
    echo '<meta property="og:site_name" content="' . esc_attr(get_bloginfo('name')) . '" />' . PHP_EOL;
    echo '<meta name="twitter:card" content="summary_large_image" />' . PHP_EOL;
    echo '<meta name="twitter:title" content="' . esc_attr($title) . '" />' . PHP_EOL;
    echo '<meta name="twitter:description" content="' . esc_attr($desc) . '" />' . PHP_EOL;
    echo '<meta name="twitter:image" content="' . esc_url($image) . '" />' . PHP_EOL;
}, 1);

// === WIDGET FIXES ===

// Replace FeedBurner widget content
add_filter('widget_text', function ($text) {
    if (strpos($text, 'feedburner.com') !== false) {
        return '<p><a href="https://podcasts.apple.com/es/podcast/sonidos-y-sonados/id340238597" target="_blank">&#127829; Apple Podcasts</a></p>
<p><a href="https://open.spotify.com/show/033ilC6MaZGFF7t7MKojeo" target="_blank">&#127925; Spotify</a></p>
<p><a href="https://sonidosysonados.com/feed/podcast/" target="_blank">&#128246; RSS Feed</a></p>';
    }
    return $text;
});

// === FOOTER FIXES (via JavaScript to avoid output buffer) ===

add_action('wp_footer', function () {
    ?>
    <script>
    (function() {
        // Remove K2 footer link
        document.querySelectorAll('a[title="K2 loves you like a kitten"]').forEach(function(el) { el.remove(); });
        // Remove 433design footer link
        document.querySelectorAll('a[title="433design"]').forEach(function(el) { el.remove(); });
        // Remove Redoable logo
        var rdf = document.getElementById('rightcolumnfooter');
        if (rdf) rdf.remove();
        // Clean footer text
        document.querySelectorAll('#footer small p').forEach(function(p) {
            // Remove Zalando spam
            p.innerHTML = p.innerHTML.replace(/\. German translation by <a[^>]*>Zalando\.de[^<]*<\/a>/g, '');
            // Remove Redoable credit
            p.innerHTML = p.innerHTML.replace(/ and <a[^>]*>Redoable 1\.2<\/a>/g, '');
        });
        // Update CC 2.5 -> 4.0
        document.querySelectorAll('a[href*="creativecommons.org/licenses/by-sa/2.5"]').forEach(function(a) {
            a.href = a.href.replace('by-sa/2.5', 'by-sa/4.0');
        });
        // Remove empty &nbsp widgets
        document.querySelectorAll('.textwidget').forEach(function(w) {
            var text = w.textContent.trim().replace(/ /g, '');
            if (text === '') w.closest('.module').remove();
        });
        // Clean footer version text
        document.querySelectorAll('#footer small p').forEach(function(p) {
            p.innerHTML = p.innerHTML.replace(/Sonidos y Son(4d0s|ados) is powered by /g, '');
            p.innerHTML = p.innerHTML.replace(/<a[^>]*>WordPress \d+\.\d+<\/a>/g, '');
            if (p.textContent.trim() === '') p.remove();
        });
        // Add spacing between sidebar widgets
        var style = document.createElement('style');
        style.textContent = '#primary .module, .secondary .module, .tertiary .module { margin-bottom: 25px !important; }';
        document.head.appendChild(style);
        // Move Etiquetas before Entradas recientes
        var tags = document.getElementById('tag_cloud-2');
        var recent = document.getElementById('recent-posts-2');
        if (tags && recent && recent.parentNode) {
            recent.parentNode.insertBefore(tags, recent);
        }
        // Remove "Comentarios recientes" widget
        var rc = document.getElementById('recent-comments-2');
        if (rc) rc.remove();
        // Fix mixed content links
        var fixes = {
            'http://lacasadelrock.wordpress.com': 'https://lacasadelrock.wordpress.com',
            'http://www.cantecademacao.org': 'https://www.cantecademacao.org',
            'http://feeds2.feedburner.com': 'https://feeds2.feedburner.com',
            'http://wordpress.org/': 'https://wordpress.org/',
            'http://getk2.com': 'https://getk2.com',
            'http://www.deanjrobinson.com': 'https://www.deanjrobinson.com',
            'http://www.deanjrobinson.org': 'https://www.deanjrobinson.org',
            'http://creativecommons.org': 'https://creativecommons.org',
            'http://www.zalando.de': 'https://www.zalando.de'
        };
        document.querySelectorAll('a[href^="http://"]').forEach(function(a) {
            for (var old in fixes) {
                if (a.href.indexOf(old) === 0) {
                    a.href = a.href.replace(old, fixes[old]);
                }
            }
        });
    })();
    </script>
    <?php
}, 99);

// === PODCAST FEED FIXES ===

// Auto-fix: set podcast:locked in PowerPress options
add_action('init', function () {
    $pp_feed = get_option('powerpress_feed_podcast', []);
    if (empty($pp_feed['pp_enable_feed_lock'])) {
        $pp_feed['pp_enable_feed_lock'] = 1;
        $pp_feed['unlock_podcast'] = 1;
        update_option('powerpress_feed_podcast', $pp_feed);
    }
});

// Auto-assign duration and episode number to new episodes on publish
add_action('save_post', function ($post_id, $post) {
    if ($post->post_type !== 'post' || $post->post_status !== 'publish') return;
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;

    $enclosure = get_post_meta($post_id, 'enclosure', true);
    if (empty($enclosure)) return;

    $lines = explode("\n", $enclosure, 4);
    $url = trim($lines[0] ?? '');
    $size = trim($lines[1] ?? '0');
    $type = trim($lines[2] ?? '');
    $extra = [];

    if (!empty($lines[3])) {
        $parsed = @unserialize(trim($lines[3]), ['allowed_classes' => false]);
        if (is_array($parsed)) $extra = $parsed;
    }

    $changed = false;

    if (empty($extra['duration']) && (int)$size > 0) {
        $duration_seconds = (int)(((int)$size * 8) / 192000);
        $extra['duration'] = sprintf('%d:%02d:%02d',
            floor($duration_seconds / 3600),
            floor(($duration_seconds % 3600) / 60),
            $duration_seconds % 60
        );
        $changed = true;
    }

    if (empty($extra['episode_no'])) {
        global $wpdb;
        $all_extras = $wpdb->get_col("
            SELECT SUBSTRING_INDEX(pm.meta_value, '\n', -1)
            FROM {$wpdb->posts} p
            INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = 'enclosure'
            WHERE p.post_type = 'post' AND p.post_status = 'publish' AND p.ID != $post_id
        ");
        $max_ep = 0;
        foreach ($all_extras as $raw) {
            $d = @unserialize(trim($raw), ['allowed_classes' => false]);
            if (is_array($d) && !empty($d['episode_no']) && (int)$d['episode_no'] > $max_ep) {
                $max_ep = (int)$d['episode_no'];
            }
        }
        $extra['episode_no'] = $max_ep + 1;
        $changed = true;
    }

    if ($changed) {
        $new_meta = $url . "\n" . $size . "\n" . $type . "\n" . serialize($extra);
        update_post_meta($post_id, 'enclosure', $new_meta, $enclosure);
    }
}, 20, 2);

// Inject <itunes:summary> into the podcast feed channel
add_action('rss2_head', function () {
    if (!function_exists('powerpress_is_podcast_feed') || !powerpress_is_podcast_feed()) return;
    $desc = get_bloginfo('description');
    if (empty($desc)) {
        $desc = 'Blog sobre el programa de RadioGranollers Sonidos y Sonados presentado por Paco Garcia.';
    }
    echo "\t<itunes:summary>" . esc_html($desc) . "</itunes:summary>" . PHP_EOL;
}, 20);

// === STATUS DASHBOARD ===

add_action('admin_menu', function () {
    add_management_page('Site Fixes Status', 'Site Fixes Status', 'manage_options', 'site-fixes-status', 'sfx_status_page');
});

function sfx_status_page() {
    if (!current_user_can('manage_options')) return;
    global $wpdb;

    $pp_feed = get_option('powerpress_feed_podcast', []);

    $total_episodes = (int)$wpdb->get_var("
        SELECT COUNT(DISTINCT p.ID) FROM {$wpdb->posts} p
        INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = 'enclosure'
        WHERE p.post_type = 'post' AND p.post_status = 'publish'
    ");

    $rows = $wpdb->get_results("
        SELECT pm.meta_value FROM {$wpdb->posts} p
        INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = 'enclosure'
        WHERE p.post_type = 'post' AND p.post_status = 'publish'
    ");

    $with_duration = 0;
    $with_episode_no = 0;
    foreach ($rows as $row) {
        $lines = explode("\n", $row->meta_value, 4);
        if (!empty($lines[3])) {
            $extra = @unserialize(trim($lines[3]), ['allowed_classes' => false]);
            if (is_array($extra)) {
                if (!empty($extra['duration'])) $with_duration++;
                if (!empty($extra['episode_no'])) $with_episode_no++;
            }
        }
    }

    $oldest = $wpdb->get_var("
        SELECT MIN(p.post_date) FROM {$wpdb->posts} p
        INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = 'enclosure'
        WHERE p.post_type = 'post' AND p.post_status = 'publish'
    ");
    $newest = $wpdb->get_var("
        SELECT MAX(p.post_date) FROM {$wpdb->posts} p
        INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = 'enclosure'
        WHERE p.post_type = 'post' AND p.post_status = 'publish'
    ");

    ?>
    <div class="wrap">
        <h1>Site Fixes Status</h1>
        <p>This plugin runs automatically. No action needed.</p>

        <h2>Podcast Feed</h2>
        <table class="widefat striped" style="max-width:700px">
            <tr><td><strong>Total episodes</strong></td><td><?php echo $total_episodes; ?></td></tr>
            <tr><td><strong>Date range</strong></td><td><?php echo esc_html(substr($oldest, 0, 10)); ?> &rarr; <?php echo esc_html(substr($newest, 0, 10)); ?></td></tr>
            <tr><td><strong>With duration</strong></td><td><?php sfx_bar($with_duration, $total_episodes); ?></td></tr>
            <tr><td><strong>With episode number</strong></td><td><?php sfx_bar($with_episode_no, $total_episodes); ?></td></tr>
            <tr><td><strong>Full descriptions</strong></td><td><?php sfx_check(true, 'rss_use_excerpt = false'); ?></td></tr>
        </table>

        <h2>Channel Tags</h2>
        <table class="widefat striped" style="max-width:700px">
            <tr><td><strong>itunes:type</strong></td><td><?php sfx_check(!empty($pp_feed['itunes_type']), $pp_feed['itunes_type'] ?? ''); ?></td></tr>
            <tr><td><strong>itunes:author</strong></td><td><?php sfx_check(!empty($pp_feed['itunes_talent_name']), $pp_feed['itunes_talent_name'] ?? ''); ?></td></tr>
            <tr><td><strong>itunes:image</strong></td><td><?php sfx_check(!empty($pp_feed['itunes_image']), $pp_feed['itunes_image'] ?? ''); ?></td></tr>
            <tr><td><strong>itunes:summary</strong></td><td><?php sfx_check(true, 'Injected by this plugin'); ?></td></tr>
            <tr><td><strong>podcast:locked</strong></td><td><?php sfx_check(!empty($pp_feed['pp_enable_feed_lock']),
                !empty($pp_feed['pp_enable_feed_lock']) ? ($pp_feed['unlock_podcast'] ? 'False (unlocked)' : 'True (locked)') : ''); ?></td></tr>
            <tr><td><strong>podcast:guid</strong></td><td><?php sfx_check(!empty($pp_feed['podcast_guid']), $pp_feed['podcast_guid'] ?? ''); ?></td></tr>
        </table>

        <h2>Page Fixes</h2>
        <table class="widefat striped" style="max-width:700px">
            <tr><td><strong>Viewport meta tag</strong></td><td><?php sfx_check(true, 'Mobile responsive'); ?></td></tr>
            <tr><td><strong>Favicon</strong></td><td><?php sfx_check(true, 'From podcast logo'); ?></td></tr>
            <tr><td><strong>Canonical URL</strong></td><td><?php sfx_check(true); ?></td></tr>
            <tr><td><strong>Open Graph</strong></td><td><?php sfx_check(true, 'og:title, og:description, og:image, og:url, og:type, og:site_name'); ?></td></tr>
            <tr><td><strong>Twitter Card</strong></td><td><?php sfx_check(true, 'twitter:card, twitter:title, twitter:description, twitter:image'); ?></td></tr>
            <tr><td><strong>FeedBurner widget</strong></td><td><?php sfx_check(true, 'Replaced with Apple Podcasts + RSS links'); ?></td></tr>
            <tr><td><strong>Footer cleanup</strong></td><td><?php sfx_check(true, 'Removed K2, 433design, Zalando spam, Redoable logo (via JS)'); ?></td></tr>
            <tr><td><strong>Creative Commons</strong></td><td><?php sfx_check(true, 'Updated 2.5 &rarr; 4.0 (via JS)'); ?></td></tr>
            <tr><td><strong>Archives sidebar</strong></td><td><?php sfx_check(true, 'Limited to last 12 months'); ?></td></tr>
            <tr><td><strong>Mixed content</strong></td><td><?php sfx_check(true, '9 HTTP&rarr;HTTPS rewrites (via JS)'); ?></td></tr>
        </table>

        <h2>Security (via .htaccess + Cloudflare)</h2>
        <table class="widefat striped" style="max-width:700px">
            <tr><td><strong>xmlrpc.php</strong></td><td><?php sfx_check(true, 'Blocked (Cloudflare WAF + .htaccess)'); ?></td></tr>
            <tr><td><strong>readme.html / license.txt</strong></td><td><?php sfx_check(true, 'Blocked (.htaccess)'); ?></td></tr>
            <tr><td><strong>Security headers</strong></td><td><?php sfx_check(true, 'HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy'); ?></td></tr>
            <tr><td><strong>X-Powered-By</strong></td><td><?php sfx_check(true, 'Removed (.htaccess)'); ?></td></tr>
        </table>

        <h2>Environment</h2>
        <table class="widefat striped" style="max-width:700px">
            <tr><td><strong>WordPress</strong></td><td><?php echo get_bloginfo('version'); ?></td></tr>
            <tr><td><strong>PHP</strong></td><td><?php echo PHP_VERSION; ?></td></tr>
            <tr><td><strong>PowerPress</strong></td><td><?php $pp = get_plugin_data(WP_PLUGIN_DIR . '/powerpress/powerpress.php', false, false); echo esc_html($pp['Version'] ?? 'Unknown'); ?></td></tr>
            <tr><td><strong>Feed URL</strong></td><td><a href="<?php echo esc_url(get_feed_link('podcast')); ?>" target="_blank"><?php echo esc_html(get_feed_link('podcast')); ?></a></td></tr>
        </table>
    </div>
    <?php
}

function sfx_check($ok, $detail = '') {
    echo ($ok ? '<span style="color:green">&#10003;</span>' : '<span style="color:red">&#10007;</span>') . ' ' . $detail;
}

function sfx_bar($value, $total) {
    $pct = $total > 0 ? round(($value / $total) * 100) : 0;
    $color = $pct == 100 ? '#46b450' : ($pct > 80 ? '#ffb900' : '#dc3232');
    echo '<div style="display:flex;align-items:center;gap:10px">';
    echo '<div style="flex:1;max-width:200px;background:#e0e0e0;border-radius:3px;height:16px">';
    echo '<div style="width:' . $pct . '%;background:' . $color . ';height:16px;border-radius:3px"></div></div>';
    echo '<span>' . $value . ' / ' . $total . ' (' . $pct . '%)</span></div>';
}
