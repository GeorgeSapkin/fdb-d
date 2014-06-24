module fdb.main;

import std.array,
       std.conv,
       std.exception,
       std.format,
       std.string;

import fdb.cluster,
       fdb.fdb_c;

private auto networkStarted = false;

void selectAPIVersion(int apiVersion) {
    auto err = fdb_select_api_version(apiVersion);
    enforce(err != 2203,
        "API version not supported by the installed FoundationDB C library");
    enforce(!err, fdb_get_error(err).to!string);
}

void runNetwork() {
    auto err = fdb_run_network();
    if (err) {
        auto writer = appender!string;
        formattedWrite(writer,
            "FoundationDB network thread encountered error: %s\n",
            fdb_get_error(err).to!string);
        enforce(!err, writer.data);
    }
}

void startNetwork() {
    if (networkStarted) return;
    networkStarted = true;
    runNetwork();
}

void stopNetwork() {
    auto err = fdb_stop_network();
    enforce(!err, fdb_get_error(err).to!string);
}

auto createCluster(string clusterFilePath) {
    FDBFuture * f = fdb_create_cluster(clusterFilePath.toStringz);
    auto err      = fdb_future_block_until_ready(f);

    FDBCluster * cluster;
    if (!err) err = fdb_future_get_cluster(f, &cluster);
    enforce(!err, fdb_get_error(err).to!string);

    return new Cluster(cluster);
}