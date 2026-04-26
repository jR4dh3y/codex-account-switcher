/* account_store.vala - Persistent storage for accounts */

namespace CodexTracker {

    public class UsageWindow : Object {
        public string name { get; set; default = ""; }
        public double used_percent { get; set; default = 0; }
        public int limit_window_seconds { get; set; default = 0; }
        public int reset_after_seconds { get; set; default = 0; }
        public int64 reset_at_epoch { get; set; default = 0; }

        public double percent_left {
            get { return double.max (0, 100.0 - used_percent); }
        }

        public UsageWindow () {}

        public string get_window_duration () {
            if (limit_window_seconds <= 0) return "";
            int hours = limit_window_seconds / 3600;
            if (hours < 24) return "%dh window".printf (hours);
            int days = hours / 24;
            return "%dd window".printf (days);
        }

        public string get_reset_countdown () {
            if (reset_after_seconds <= 0) return "";
            int secs = reset_after_seconds;
            int days = secs / 86400;
            secs %= 86400;
            int hours = secs / 3600;
            secs %= 3600;
            int mins = secs / 60;

            if (days > 0)
                return "Resets in %dd %dh".printf (days, hours);
            else if (hours > 0)
                return "Resets in %dh %dm".printf (hours, mins);
            else
                return "Resets in %dm".printf (mins);
        }
    }

    public class AccountData : Object {
        public string label { get; set; default = ""; }
        public string email { get; set; default = ""; }
        public string access_token { get; set; default = ""; }
        public string refresh_token { get; set; default = ""; }
        public string id_token { get; set; default = ""; }
        public string account_id { get; set; default = ""; }
        public string plan_type { get; set; default = "unknown"; }

        // Usage state
        public string usage_status { get; set; default = "unknown"; }
        public string last_checked { get; set; default = "never"; }
        public string usage_raw_json { get; set; default = ""; }
        public string error_message { get; set; default = ""; }

        // Rate limit info
        public bool limit_reached { get; set; default = false; }
        public bool is_allowed { get; set; default = true; }

        // Parsed usage windows
        public GenericArray<UsageWindow> usage_windows { get; set; }

        public AccountData () {
            usage_windows = new GenericArray<UsageWindow> ();
        }

        public AccountData.from_json (Json.Object obj) {
            usage_windows = new GenericArray<UsageWindow> ();

            if (obj.has_member ("label"))
                this.label = obj.get_string_member ("label");
            if (obj.has_member ("email"))
                this.email = obj.get_string_member ("email");
            if (obj.has_member ("access_token"))
                this.access_token = obj.get_string_member ("access_token");
            if (obj.has_member ("refresh_token"))
                this.refresh_token = obj.get_string_member ("refresh_token");
            if (obj.has_member ("id_token"))
                this.id_token = obj.get_string_member ("id_token");
            if (obj.has_member ("account_id"))
                this.account_id = obj.get_string_member ("account_id");
            if (obj.has_member ("plan_type"))
                this.plan_type = obj.get_string_member ("plan_type");
        }

        public Json.Object to_json () {
            var obj = new Json.Object ();
            obj.set_string_member ("label", label);
            obj.set_string_member ("email", email);
            obj.set_string_member ("access_token", access_token);
            obj.set_string_member ("refresh_token", refresh_token);
            obj.set_string_member ("id_token", id_token);
            obj.set_string_member ("account_id", account_id);
            obj.set_string_member ("plan_type", plan_type);
            return obj;
        }
    }

    public class AccountStore : Object {
        private string config_dir;
        private string config_file;
        public GenericArray<AccountData> accounts { get; private set; }

        public AccountStore () {
            config_dir = Path.build_filename (Environment.get_user_config_dir (), "codex-multi-account-switcher");
            config_file = Path.build_filename (config_dir, "accounts.json");
            accounts = new GenericArray<AccountData> ();
        }

        public void load () {
            accounts = new GenericArray<AccountData> ();

            if (!FileUtils.test (config_file, FileTest.EXISTS))
                return;

            try {
                string contents;
                FileUtils.get_contents (config_file, out contents);

                var parser = new Json.Parser ();
                parser.load_from_data (contents);

                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.ARRAY)
                    return;

                var arr = root.get_array ();
                for (uint i = 0; i < arr.get_length (); i++) {
                    var obj = arr.get_object_element (i);
                    var account = new AccountData.from_json (obj);
                    accounts.add (account);
                }
            } catch (Error e) {
                warning ("Failed to load accounts: %s", e.message);
            }
        }

        public void save () {
            DirUtils.create_with_parents (config_dir, 0700);

            var arr = new Json.Array ();
            for (uint i = 0; i < accounts.length; i++) {
                var node = new Json.Node (Json.NodeType.OBJECT);
                node.set_object (accounts[i].to_json ());
                arr.add_element (node);
            }

            var root = new Json.Node (Json.NodeType.ARRAY);
            root.set_array (arr);

            var gen = new Json.Generator ();
            gen.set_root (root);
            gen.pretty = true;

            try {
                gen.to_file (config_file);
                FileUtils.chmod (config_file, 0600);
            } catch (Error e) {
                warning ("Failed to save accounts: %s", e.message);
            }
        }

        public void add_account (AccountData account) {
            accounts.add (account);
            save ();
        }

        public void remove_account (uint index) {
            if (index < accounts.length) {
                accounts.remove_index (index);
                save ();
            }
        }

        public static void extract_jwt_info (AccountData account) {
            if (account.id_token == "")
                return;

            var parts = account.id_token.split (".");
            if (parts.length < 2)
                return;

            try {
                string payload_b64 = parts[1];
                while (payload_b64.length % 4 != 0)
                    payload_b64 += "=";

                payload_b64 = payload_b64.replace ("-", "+").replace ("_", "/");

                var decoded = Base64.decode (payload_b64);
                var payload_str = (string) decoded;

                var parser = new Json.Parser ();
                parser.load_from_data (payload_str);
                var obj = parser.get_root ().get_object ();

                if (obj.has_member ("email"))
                    account.email = obj.get_string_member ("email");

                if (obj.has_member ("https://api.openai.com/auth")) {
                    var auth = obj.get_object_member ("https://api.openai.com/auth");
                    if (auth.has_member ("chatgpt_plan_type"))
                        account.plan_type = auth.get_string_member ("chatgpt_plan_type");
                    if (auth.has_member ("chatgpt_account_id"))
                        account.account_id = auth.get_string_member ("chatgpt_account_id");
                }
            } catch (Error e) {
                warning ("Failed to decode JWT: %s", e.message);
            }
        }
    }
}
