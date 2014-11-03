module fdb.database;

import
    std.conv,
    std.exception,
    std.string;

import
    fdb.cluster,
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.future,
    fdb.transaction;

class Database
{
    private const Cluster   cluster;
    private DatabaseHandle  dbh;

    this(const Cluster cluster, DatabaseHandle dbh)
    {
        this.cluster    = cluster;
        this.dbh        = dbh;
    }

    ~this()
    {
        destroy;
    }

    void destroy()
    {
        if (dbh)
        {
            fdb_database_destroy(dbh);
            dbh = null;
        }
    }

    auto createTransaction() const
    {
        TransactionHandle th;
        fdb_database_create_transaction(dbh, &th).enforceError;
        return new Transaction(this, th);
    }

    /**
     * Set the size of the client location cache. Raising this value can boost
     * performance in very large databases where clients access data in a near-
     * random pattern. Defaults to 100000.
     * Parameter: (Int) Max location cache entries
     */
    void setLocationCacheSize(const long value) const
    {
        setDatabaseOption(DatabaseOption.LOCATION_CACHE_SIZE, value);
    }

    /**
     * Set the maximum number of watches allowed to be outstanding on a database
     * connection. Increasing this number could result in increased resource
     * usage. Reducing this number will not cancel any outstanding watches.
     * Defaults to 10000 and cannot be larger than 1000000.
     * Parameter: (Int) Max outstanding watches
     */
    void setMaxWatches(const long value) const
    {
        setDatabaseOption(DatabaseOption.MAX_WATCHES, value);
    }

    /**
     * Specify the machine ID that was passed to fdbserver processes running on
     * the same machine as this client, for better location-aware load
     * balancing.
     * Parameter: (String) Hexadecimal ID
     */
    void setMachineId(const string value) const
    {
        setDatabaseOption(DatabaseOption.MACHINE_ID, value);
    }

    /**
     * Specify the datacenter ID that was passed to fdbserver processes running
     * in the same datacenter as this client, for better location-aware load
     * balancing.
     * Parameter: (String) Hexadecimal ID
     */
    void setDatacenterId(const string value) const
    {
        setDatabaseOption(DatabaseOption.DATACENTER_ID, value);
    }

    private void setDatabaseOption(
        const DatabaseOption    op,
        const long              value) const
    {
        const auto err = fdb_database_set_option(
            dbh,
            op,
            cast(immutable(char)*)&value,
            cast(int)value.sizeof);
        enforceError(err);
    }

    private void setDatabaseOption(
        const DatabaseOption    op,
        const string            value) const
    {
        const auto err = fdb_database_set_option(
            dbh,
            op,
            value.toStringz,
            cast(int)value.length);
        enforceError(err);
    }
}

alias WorkFunc = void delegate(Transaction tr, VoidFutureCallback cb);

auto doTransaction(
    Database db,
    WorkFunc func,
    VoidFutureCallback commitCallback)
{
    auto tr = db.createTransaction();
    auto future = createFuture!doTransactionWorker(tr, func, commitCallback);
    return future;
};

void doTransactionWorker(
    Transaction         tr,
    WorkFunc            func,
    VoidFutureCallback  commitCallback,
    CompletionCallback  futureCompletionCallback)
{
    retryLoop(tr, func, (ex)
    {
        commitCallback(ex);
        futureCompletionCallback(ex);
    });
}

private void retryLoop(
    Transaction tr,
    WorkFunc func,
    VoidFutureCallback cb)
{
    func(tr, (ex)
    {
        if (ex)
            onError(tr, ex, func, cb);
        else
            tr.commit((commitErr)
            {
                if (commitErr)
                    onError(tr, commitErr, func, cb);
                else
                    cb(commitErr);
            });
    });
}

private void onError(
    Transaction tr,
    Exception ex,
    WorkFunc func,
    VoidFutureCallback cb)
{
    if (auto fdbex = cast(FDBException)ex)
    {
        tr.onError(fdbex, (retryErr)
        {
            if (retryErr)
                cb(retryErr);
            else
                retryLoop(tr, func, cb);
        });
    }
    else
    {
        tr.cancel();
        cb(ex);
    }
};