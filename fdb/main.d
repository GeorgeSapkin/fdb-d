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
    fdb.networkoptions;

private shared auto networkStarted = false;
private Task!(networkThread) * networkTask;

private auto FBD_RUNTIME_API_VERSION = 200;

shared static this()
{
    selectAPIVersion(FBD_RUNTIME_API_VERSION);
}

void selectAPIVersion(int apiVersion)
{
    enforceError(fdb_select_api_version(apiVersion));
}

auto networkThread()
{
    return fdb_run_network();
}

private void runNetwork()
{
    NetworkOptions.init;
    enforceError(fdb_setup_network);
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
    enforceError(fdb_stop_network);
    if (networkTask)
        enforceError(networkTask.yieldForce);
    networkStarted = false;
}

auto createCluster(string clusterFilePath)
{
    const FDBFuture * f = fdb_create_cluster(clusterFilePath.toStringz);
    enforceError(fdb_future_block_until_ready(f));

    FDBCluster * cluster;
    enforceError(fdb_future_get_cluster(f, &cluster));

    return new Cluster(cluster);
}