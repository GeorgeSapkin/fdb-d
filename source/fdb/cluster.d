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

class Cluster : IDisposable
{
    private ClusterHandle ch;

    private Database[] databases;
    private shared auto dbLock = new Object;

    this(ClusterHandle ch)
    in
    {
        enforce(ch !is null, "ch must be set");
    }
    body
    {
        this.ch = ch;
    }

    void dispose()
    {
        synchronized (dbLock)
            foreach (db; databases)
                db.dispose;

        if (!ch) return;

        fdb_cluster_destroy(ch);
        ch = null;
    }

    auto openDatabase(in string dbName = "DB")
    out (result)
    {
        assert(result !is null);
    }
    body
    {
        auto fh = fdb_cluster_create_database(
            ch,
            dbName.toStringz,
            cast(int)dbName.length);

        scope auto future = createFuture!VoidFuture(fh);
        future.await;

        DatabaseHandle dbh;
        const err = fdb_future_get_database(fh, &dbh);
        enforceError(err);

        auto db = new Database(dbh, this);
        synchronized (dbLock)
            databases ~= db;
        return db;
    }
}
