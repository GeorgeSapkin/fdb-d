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
    private ClusterHandle ch;

    this(ClusterHandle ch)
    {
        this.ch = ch;
    }

    ~this()
    {
        destroy;
    }

    void destroy()
    {
        if (ch)
        {
            fdb_cluster_destroy(ch);
            ch = null;
        }
    }

    auto openDatabase(const string dbName = "DB")
    {
        auto fh = fdb_cluster_create_database(
            ch,
            dbName.toStringz(),
            cast(int)dbName.length);
        scope auto future = createFuture!VoidFuture(fh);
        future.wait;

        DatabaseHandle dbh;
        fdb_future_get_database(fh, &dbh).enforceError;
        return new Database(this, dbh);
    }
}