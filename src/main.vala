/* main.vala - Entry point */

private bool path_list_has_dir (string path_list, string dir) {
    foreach (var path in path_list.split (":")) {
        if (path == dir)
            return true;
    }

    return false;
}

private void ensure_system_data_dirs () {
    const string usr_share = "/usr/share";
    const string local_share = "/usr/local/share";
    string? data_dirs = Environment.get_variable ("XDG_DATA_DIRS");

    if (data_dirs == null || data_dirs == "") {
        Environment.set_variable ("XDG_DATA_DIRS", "%s:%s".printf (local_share, usr_share), true);
        return;
    }

    string fixed_dirs = data_dirs;
    if (!path_list_has_dir (fixed_dirs, local_share))
        fixed_dirs = "%s:%s".printf (fixed_dirs, local_share);
    if (!path_list_has_dir (fixed_dirs, usr_share))
        fixed_dirs = "%s:%s".printf (fixed_dirs, usr_share);

    if (fixed_dirs != data_dirs)
        Environment.set_variable ("XDG_DATA_DIRS", fixed_dirs, true);
}

private void ensure_gsettings_schema_dir () {
    string? schema_dir = Environment.get_variable ("GSETTINGS_SCHEMA_DIR");
    if (schema_dir == null || schema_dir == "")
        return;

    string compiled_schema = Path.build_filename (schema_dir, "gschemas.compiled");
    if (FileUtils.test (compiled_schema, FileTest.EXISTS))
        return;

    string system_schema_dir = "/usr/share/glib-2.0/schemas";
    string system_compiled_schema = Path.build_filename (system_schema_dir, "gschemas.compiled");
    if (FileUtils.test (system_compiled_schema, FileTest.EXISTS))
        Environment.set_variable ("GSETTINGS_SCHEMA_DIR", system_schema_dir, true);
    else
        Environment.unset_variable ("GSETTINGS_SCHEMA_DIR");
}

int main (string[] args) {
    ensure_system_data_dirs ();
    ensure_gsettings_schema_dir ();

    var app = new CodexTracker.Application ();
    return app.run (args);
}
