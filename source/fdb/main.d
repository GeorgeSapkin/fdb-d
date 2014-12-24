module fdb.main;

import
    std.array,
    std.concurrency,
    std.conv,
    std.exception,
    std.format,
    std.string;

import
    fdb.cluster,
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.future,
    fdb.networkoptions;

private shared auto networkStarted = false;
private shared bool apiSelected    = false;

private auto FBD_RUNTIME_API_VERSION = FDB_API_VERSION;

void selectAPIVersion(const int apiVersion)
in
{
    enforce(!apiSelected, "API version already selected");
}
body
{
    auto err = fdb_select_api_version(apiVersion);
    enforceError(err);
}

auto networkThread()
in
{
    assert(ownerTid != Tid.init);
}
body
{
    auto err = fdb_run_network();
    ownerTid.send(err);
}

void startNetwork()
in
{
    assert(!networkStarted);
}
body
{
    if (networkStarted) return;

    if (!apiSelected)
        selectAPIVersion(FBD_RUNTIME_API_VERSION);

    NetworkOptions.init;
    auto err       = fdb_setup_network();
    enforceError(err);

    spawn(&networkThread);
    networkStarted = true;
}

void stopNetwork()
in
{
    assert(networkStarted);
}
body
{
    if (!networkStarted) return;

    auto err       = fdb_stop_network();
    enforceError(err);

    auto taskErr   = receiveOnly!fdb_error_t;
    enforceError(taskErr);

    networkStarted = false;
}

auto createCluster(const string clusterFilePath = null)
in
{
    assert(networkStarted);
}
out (result)
{
    assert(result !is null);
}
body
{
    auto fh           = fdb_create_cluster(clusterFilePath.toStringz);
    scope auto future = createFuture!VoidFuture(fh);
    future.await;

    ClusterHandle ch;
    auto err          = fdb_future_get_cluster(fh, &ch);
    enforceError(err);

    return new shared Cluster(ch);
}

auto open(const string clusterFilePath = null)
{
    startNetwork;
    auto cluster = createCluster(clusterFilePath);
    auto db      = cluster.openDatabase;
    return db;
}

alias close = stopNetwork;
