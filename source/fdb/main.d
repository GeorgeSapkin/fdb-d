module fdb.main;

import
    std.concurrency,
    std.exception,
    std.string;

import
    fdb.cluster,
    fdb.error,
    fdb.fdb_c,
    fdb.future,
    fdb.networkoptions;

private shared
{
    auto networkStarted = false;
    bool apiSelected    = false;

    Cluster cluster;
}

private auto FBD_RUNTIME_API_VERSION = FDB_API_VERSION;

void selectAPIVersion(in int apiVersion)
in
{
    enforce(!apiSelected, "API version already selected");
}
body
{
    const err = fdb_select_api_version(apiVersion);
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

private void startNetwork()
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
    const err = fdb_setup_network();
    enforceError(err);

    spawn(&networkThread);
    networkStarted = true;
}

private void stopNetwork()
in
{
    assert(networkStarted);
}
body
{
    if (!networkStarted) return;

    const err = fdb_stop_network();
    enforceError(err);

    const taskErr = receiveOnly!fdb_error_t;
    enforceError(taskErr);

    networkStarted = false;
}

private auto createCluster(in string clusterFilePath = null)
in
{
    assert(networkStarted);
}
body
{
    auto fh = fdb_create_cluster(clusterFilePath.toStringz);
    scope auto future = createFuture!VoidFuture(fh);
    future.await;

    ClusterHandle ch;
    const err = fdb_future_get_cluster(fh, &ch);
    enforceError(err);

    return new Cluster(ch);
}

auto open(in string clusterFilePath = null)
{
    startNetwork;

    auto cl = createCluster(clusterFilePath);
    cluster = cast(shared)cl;

    auto db = cl.openDatabase;
    return db;
}

void close()
{
    auto cl = cast(Cluster)cluster;
    cl.dispose;

    stopNetwork;
}
