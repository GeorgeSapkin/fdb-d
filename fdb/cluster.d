module fdb.cluster;

import std.conv,
       std.exception,
       std.string;

import fdb.database,
       fdb.fdb_c,
       fdb.helpers;

class Cluster {
    private ClusterHandle cluster;

    this(ClusterHandle cluster) { this.cluster = cluster; }

    ~this() { destroy; }

    void destroy() { fdb_cluster_destroy(cluster); }

    auto openDatabase(string dbName) {
        auto f = fdb_cluster_create_database(
            cluster,
            dbName.toStringz(),
            cast(int)dbName.length);

        auto err = fdb_future_block_until_ready(f);

        DatabaseHandle database;
        if (!err)
			err = fdb_future_get_database(f, &database);

        enforce(!err, err.message);

        return new Database(database);
    }
}