module fdb.main;

import
    std.array,
    std.conv,
    std.exception,
    std.format,
    std.parallelism,
    std.string;

import
    fdb.cluster,
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.future,
    fdb.networkoptions;

private shared auto networkStarted = false;
private Task!(networkThread) * networkTask;

private auto FBD_RUNTIME_API_VERSION = 200;

shared static this()
{
    selectAPIVersion(FBD_RUNTIME_API_VERSION);
}

private void selectAPIVersion(const int apiVersion)
{
    fdb_select_api_version(apiVersion).enforceError;
}

auto networkThread()
{
    return fdb_run_network();
}

private void runNetwork()
{
    NetworkOptions.init;
    fdb_setup_network.enforceError;
    networkTask = task!networkThread;
    networkTask.executeInNewThread;
}

void startNetwork()
{
    if (networkStarted) return;
    runNetwork();
    networkStarted = true;
}

void stopNetwork()
{
    fdb_stop_network.enforceError;
    if (networkTask)
        networkTask.yieldForce.enforceError;
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
    auto fh = fdb_create_cluster(clusterFilePath.toStringz);
    scope auto future = createFuture!VoidFuture(fh);
    future.await;

    ClusterHandle ch;
    fdb_future_get_cluster(fh, &ch).enforceError;

    return new Cluster(ch);
}
