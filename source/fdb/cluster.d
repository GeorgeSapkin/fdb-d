module fdb.cluster;

import
    std.conv,
    std.exception,
    std.string;

import
    fdb.database,
    fdb.disposable,
    fdb.error,
    fdb.fdb_c,
    fdb.future;

shared class Cluster : IDisposable
{
    private ClusterHandle ch;

    private Database[]    databases;

    this(ClusterHandle ch)
    in
    {
        enforce(ch !is null, "ch must be set");
    }
    body
    {
        this.ch = cast(shared)ch;
    }

    ~this()
    {
        dispose;
    }

    void dispose()
    {
        if (!ch) return;

        fdb_cluster_destroy(cast(ClusterHandle)ch);
        ch = null;
    }

    auto openDatabase(const string dbName = "DB")
    out (result)
    {
        assert(result !is null);
    }
    body
    {
        auto fh            = fdb_cluster_create_database(
            cast(ClusterHandle)ch,
            dbName.toStringz(),
            cast(int)dbName.length);
        scope auto future  = createFuture!VoidFuture(fh);
        future.await;

        DatabaseHandle dbh;
        auto err           = fdb_future_get_database(fh, &dbh);
        enforceError(err);

        auto db            = new shared Database(dbh, this);
        synchronized (this)
            databases     ~= db;
        return db;
    }
}
