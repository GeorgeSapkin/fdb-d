module fdb.cluster;

import std.conv,
       std.exception,
       std.string;

import fdb.database,
       fdb.fdb_c;

class Cluster {
    private FDBCluster * cluster;

    this(FDBCluster * cluster) { this.cluster = cluster; }

    ~this() { destroy; }

    void destroy() { fdb_cluster_destroy(cluster); }

    auto openDatabase(string dbName) {
        FDBFuture * f = fdb_cluster_create_database(
            cluster,
            dbName.toStringz(),
            cast(int)dbName.length);

        auto err = fdb_future_block_until_ready(f);

        FDBDatabase * database;
        if (!err) err = fdb_future_get_database(f, &database);
        enforce(!err, fdb_get_error(err).to!string);

        return new Database(database);
    }
}