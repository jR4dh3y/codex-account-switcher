/* auth_manager.vala - OAuth PKCE Browser Login Flow (matching OpenCode's implementation) */

namespace CodexTracker {

    // OAuth constants from OpenCode's codex.ts plugin
    private const string CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann";
    private const string AUTH_URL = "https://auth.openai.com/oauth/authorize";
    private const string TOKEN_URL = "https://auth.openai.com/oauth/token";
    private const string SCOPE = "openid profile email offline_access";

    public class AuthManager : Object {
        private Soup.Session http_session;
        private Cancellable? active_cancellable = null;
        private SocketListener? active_listener = null;

        public signal void auth_completed (AccountData account);
        public signal void auth_failed (string error_message);
        public signal void browser_opened ();

        public AuthManager () {
            http_session = new Soup.Session ();
        }

        public void cancel () {
            if (active_cancellable != null)
                active_cancellable.cancel ();
            if (active_listener != null) {
                active_listener.close ();
                active_listener = null;
            }
        }

        // PKCE verifier: 43 random chars from unreserved charset
        private string generate_code_verifier () {
            const string charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
            var sb = new StringBuilder ();
            for (int i = 0; i < 43; i++) {
                int idx = Random.int_range (0, charset.length);
                sb.append_c (charset[idx]);
            }
            return sb.str;
        }

        // PKCE challenge: SHA-256 of verifier → base64url
        private string generate_code_challenge (string verifier) {
            var checksum = new Checksum (ChecksumType.SHA256);
            checksum.update (verifier.data, verifier.data.length);
            uint8[] digest = new uint8[32];
            size_t digest_len = 32;
            checksum.get_digest (digest, ref digest_len);
            string b64 = Base64.encode (digest);
            return b64.replace ("+", "-").replace ("/", "_").replace ("=", "");
        }

        private string generate_state () {
            uint8[] random = new uint8[16];
            for (int i = 0; i < 16; i++)
                random[i] = (uint8) Random.int_range (0, 256);
            return Base64.encode (random).replace ("+", "-").replace ("/", "_").replace ("=", "");
        }

        public async void start_browser_flow () {
            cancel ();

            string code_verifier = generate_code_verifier ();
            string code_challenge = generate_code_challenge (code_verifier);
            string state = generate_state ();

            active_listener = new SocketListener ();
            uint16 port = 1455;
            try {
                var addr = new InetSocketAddress (new InetAddress.loopback (SocketFamily.IPV4), port);
                active_listener.add_address (addr, SocketType.STREAM, SocketProtocol.TCP, null, null);
            } catch (Error e) {
                auth_failed ("Port %u is busy. Please close any running codex/opencode CLI and try again. (%s)".printf (port, e.message));
                return;
            }

            string redirect_uri = "http://localhost:%u/auth/callback".printf (port);

            // Build authorization URL — matching OpenCode exactly
            // Key params: response_type, client_id, redirect_uri, scope,
            //   code_challenge, code_challenge_method, state,
            //   id_token_add_organizations, codex_cli_simplified_flow, originator
            string auth_uri = "%s?response_type=code&client_id=%s&redirect_uri=%s&scope=%s&code_challenge=%s&code_challenge_method=S256&state=%s&id_token_add_organizations=true&codex_cli_simplified_flow=true&originator=codex-account-switcher".printf (
                AUTH_URL,
                GLib.Uri.escape_string (CLIENT_ID, null, false),
                GLib.Uri.escape_string (redirect_uri, null, false),
                GLib.Uri.escape_string (SCOPE, null, false),
                GLib.Uri.escape_string (code_challenge, null, false),
                GLib.Uri.escape_string (state, null, false)
            );

            // Open browser
            try {
                AppInfo.launch_default_for_uri (auth_uri, null);
                browser_opened ();
            } catch (Error e) {
                auth_failed ("Could not open browser: %s".printf (e.message));
                cleanup_listener ();
                return;
            }

            // Wait for callback
            active_cancellable = new Cancellable ();
            string? auth_code = null;
            string? received_state = null;

            uint timeout_id = Timeout.add_seconds (300, () => {
                if (active_cancellable != null)
                    active_cancellable.cancel ();
                return false;
            });

            try {
                var connection = yield active_listener.accept_async (active_cancellable, null);
                Source.remove (timeout_id);

                var input = new DataInputStream (connection.input_stream);
                input.set_newline_type (DataStreamNewlineType.CR_LF);

                string? request_line = yield input.read_line_async (Priority.DEFAULT, null, null);

                // Parse: "GET /auth/callback?code=...&state=... HTTP/1.1"
                if (request_line != null) {
                    var parts = request_line.split (" ");
                    if (parts.length >= 2) {
                        string path = parts[1];
                        int qmark = path.index_of ("?");
                        if (qmark >= 0) {
                            string query = path.substring (qmark + 1);
                            foreach (string param in query.split ("&")) {
                                var kv = param.split ("=", 2);
                                if (kv.length == 2) {
                                    if (kv[0] == "code")
                                        auth_code = GLib.Uri.unescape_string (kv[1]);
                                    else if (kv[0] == "state")
                                        received_state = GLib.Uri.unescape_string (kv[1]);
                                }
                            }
                        }
                    }
                }

                // Read remaining headers
                string? line = "";
                while (line != null && line != "") {
                    line = yield input.read_line_async (Priority.DEFAULT, null, null);
                }

                // Respond to browser
                string html = auth_code != null
                    ? """<!DOCTYPE html><html><head><meta charset="utf-8"><title>Codex Account Switcher</title>
                        <style>body{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#1a1a2e;color:#e0e0e0}.box{text-align:center}h1{color:#2ec27e;font-size:28px}p{color:#9a9996}</style>
                        </head><body><div class="box"><h1>&#10003; Signed in!</h1><p>Return to Codex Account Switcher. You can close this tab.</p></div></body></html>"""
                    : """<!DOCTYPE html><html><head><meta charset="utf-8"><title>Codex Account Switcher</title>
                        <style>body{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#1a1a2e;color:#e0e0e0}.box{text-align:center}h1{color:#e01b24;font-size:28px}p{color:#9a9996}</style>
                        </head><body><div class="box"><h1>&#10007; Failed</h1><p>Try again from Codex Account Switcher.</p></div></body></html>""";

                string http_response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s".printf (html.data.length, html);
                try {
                    yield connection.output_stream.write_all_async (http_response.data, Priority.DEFAULT, null, null);
                } catch { }

                try {
                    yield connection.close_async (Priority.DEFAULT, null);
                } catch { }

            } catch (IOError.CANCELLED e) {
                cleanup_listener ();
                auth_failed ("Login timed out. Please try again.");
                return;
            } catch (Error e) {
                cleanup_listener ();
                auth_failed ("Callback error: %s".printf (e.message));
                return;
            }

            cleanup_listener ();

            if (auth_code == null) {
                auth_failed ("No authorization code received from browser.");
                return;
            }

            if (received_state != null && received_state != state) {
                auth_failed ("Security error: state mismatch. Please try again.");
                return;
            }

            yield exchange_code (auth_code, code_verifier, redirect_uri);
        }

        private void cleanup_listener () {
            if (active_listener != null) {
                active_listener.close ();
                active_listener = null;
            }
            active_cancellable = null;
        }

        private async void exchange_code (string code, string code_verifier, string redirect_uri) {
            try {
                var msg = new Soup.Message ("POST", TOKEN_URL);
                var body = "grant_type=authorization_code&client_id=%s&code=%s&redirect_uri=%s&code_verifier=%s".printf (
                    GLib.Uri.escape_string (CLIENT_ID, null, false),
                    GLib.Uri.escape_string (code, null, false),
                    GLib.Uri.escape_string (redirect_uri, null, false),
                    GLib.Uri.escape_string (code_verifier, null, false)
                );
                msg.set_request_body_from_bytes (
                    "application/x-www-form-urlencoded",
                    new Bytes (body.data)
                );

                var response_bytes = yield http_session.send_and_read_async (msg, Priority.DEFAULT, null);
                var response_str = (string) response_bytes.get_data ();

                if (msg.status_code != 200) {
                    try {
                        var parser = new Json.Parser ();
                        parser.load_from_data (response_str);
                        var obj = parser.get_root ().get_object ();
                        string err = obj.has_member ("error_description")
                            ? obj.get_string_member ("error_description")
                            : obj.get_string_member ("error");
                        auth_failed ("Token exchange failed: %s".printf (err));
                    } catch {
                        auth_failed ("Token exchange failed (HTTP %u)".printf (msg.status_code));
                    }
                    return;
                }

                var parser = new Json.Parser ();
                parser.load_from_data (response_str);
                var obj = parser.get_root ().get_object ();

                var account = new AccountData ();
                account.access_token = obj.get_string_member ("access_token");
                if (obj.has_member ("refresh_token"))
                    account.refresh_token = obj.get_string_member ("refresh_token");
                if (obj.has_member ("id_token"))
                    account.id_token = obj.get_string_member ("id_token");

                AccountStore.extract_jwt_info (account);
                account.label = account.email != "" ? account.email : "Account";

                auth_completed (account);

            } catch (Error e) {
                auth_failed ("Token exchange error: %s".printf (e.message));
            }
        }

        public async bool refresh_token (AccountData account) {
            if (account.refresh_token == "")
                return false;

            try {
                var msg = new Soup.Message ("POST", TOKEN_URL);
                var body = "client_id=%s&refresh_token=%s&grant_type=refresh_token".printf (
                    GLib.Uri.escape_string (CLIENT_ID, null, false),
                    GLib.Uri.escape_string (account.refresh_token, null, false)
                );
                msg.set_request_body_from_bytes (
                    "application/x-www-form-urlencoded",
                    new Bytes (body.data)
                );

                var response_bytes = yield http_session.send_and_read_async (msg, Priority.DEFAULT, null);
                var response_str = (string) response_bytes.get_data ();

                if (msg.status_code == 200) {
                    var parser = new Json.Parser ();
                    parser.load_from_data (response_str);
                    var obj = parser.get_root ().get_object ();

                    account.access_token = obj.get_string_member ("access_token");
                    if (obj.has_member ("refresh_token"))
                        account.refresh_token = obj.get_string_member ("refresh_token");
                    if (obj.has_member ("id_token"))
                        account.id_token = obj.get_string_member ("id_token");

                    AccountStore.extract_jwt_info (account);
                    return true;
                }
            } catch (Error e) {
                warning ("Token refresh failed: %s", e.message);
            }

            return false;
        }
    }
}
