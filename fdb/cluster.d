module fdb.cluster;

import
    std.conv,
    std.exception,
    std.string;

import
    fdb.database,
    fdb.error,
    fdb.fdb_c;

class Cluster
{
    private ClusterHandle cluster;

    this(ClusterHandle cluster)
    {
        this.cluster = cluster;
    }

    ~this()
    {
        destroy;
    }

    void destroy()
    {
        fdb_cluster_destroy(cluster);
    }

    auto openDatabase(string dbName = "DB")
    {
        auto f = fdb_cluster_create_database(
            cluster,
            dbName.toStringz(),
            cast(int)dbName.length);

        enforceError(fdb_future_block_until_ready(f));

        DatabaseHandle database;
        enforceError(fdb_future_get_database(f, &database));
        return new Database(database);
    }
}