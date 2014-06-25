module fdb.main;

import std.array,
       std.conv,
       std.exception,
       std.format,
       std.parallelism,
       std.string;

import fdb.cluster,
       fdb.fdb_c,
       fdb.fdb_c_options,
       fdb.helpers,
       fdb.networkoptions;

private shared auto networkStarted = false;
private Task!(networkThread) * networkTask;

void selectAPIVersion(int apiVersion) {
    int err = fdb_select_api_version(apiVersion);
    enforce(err != 2203,
        "API version not supported by the installed FoundationDB C library");
    enforce(!err, err.message);
}

auto networkThread() {
    return fdb_run_network();
}

private void runNetwork() {
    NetworkOptions.init;

    auto err = fdb_setup_network();
    if (err == 0) {
        networkTask = task!networkThread;
        networkTask.executeInNewThread;
    }

    if (err) {
        auto writer = appender!string;
        formattedWrite(writer,
            "FoundationDB network thread encountered error: %s\n",
            err.message);
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
    if (!err && networkTask)
        err = networkTask.yieldForce;
    enforce(!err, err.message);
    networkStarted = false;
}

auto createCluster(string clusterFilePath) {
    const FDBFuture * f = fdb_create_cluster(clusterFilePath.toStringz);
    auto err = fdb_future_block_until_ready(f);

	FDBCluster * cluster;
    if (err == 0)
		err = fdb_future_get_cluster(f, &cluster);

    enforce(!err, err.message);

    return new Cluster(cluster);
}