module fdb.cluster;

import
    std.conv,
    std.exception,
    std.string;

import
    fdb.database,
    fdb.error,
    fdb.fdb_c,
    fdb.future;

class Cluster
{
    private const ClusterHandle ch;

    this(const ClusterHandle ch)
    {
        this.ch = ch;
    }

    ~this()
    {
        destroy;
    }

    void destroy()
    {
        fdb_cluster_destroy(ch);
    }

    auto openDatabase(const string dbName = "DB")
    {
        auto f = fdb_cluster_create_database(
            ch,
            dbName.toStringz(),
            cast(int)dbName.length);
        scope auto _future = createFuture!VoidFuture(f); 
        _future.wait();

        DatabaseHandle database;
        enforceError(fdb_future_get_database(f, &database));
        return new Database(this, database);
    }
}