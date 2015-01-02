module fdb.database;

import
    std.conv,
    std.exception,
    std.string,
    std.traits;

import
    fdb.cluster,
    fdb.direct,
    fdb.disposable,
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.future,
    fdb.range,
    fdb.rangeinfo,
    fdb.transaction;

shared class Database : IDirect, IDisposable
{
    private const Cluster  cluster;
    private DatabaseHandle dbh;

    private Transaction[]  transactions;

    invariant()
    {
        assert(cluster !is null);
    }

    this(DatabaseHandle dbh, const shared Cluster cluster)
    in
    {
        enforce(cluster !is null, "cluster must be set");
        enforce(dbh !is null, "dbh must be set");
    }
    body
    {
        this.dbh     = cast(shared)dbh;
        this.cluster = cluster;
    }

    ~this()
    {
        dispose;
    }

    void dispose()
    {
        if (!dbh) return;

        fdb_database_destroy(cast(DatabaseHandle)dbh);
        dbh = null;
    }

    auto createTransaction()
    out (result)
    {
        assert(result !is null);
    }
    body
    {
        TransactionHandle th;
        auto err = fdb_database_create_transaction(
            cast(DatabaseHandle)dbh,
            &th);
        enforceError(err);

        auto tr = new shared Transaction(th, this);
        synchronized (this)
            transactions ~= tr;
        return tr;
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
        const DatabaseOption op,
        const long           value) const
    {
        const auto err = fdb_database_set_option(
            cast(DatabaseHandle)dbh,
            op,
            cast(immutable(char)*)&value,
            cast(int)value.sizeof);
        enforceError(err);
    }

    private void setDatabaseOption(
        const DatabaseOption op,
        const string         value) const
    {
        const auto err = fdb_database_set_option(
            cast(DatabaseHandle)dbh,
            op,
            value.toStringz,
            cast(int)value.length);
        enforceError(err);
    }

    shared(Value) opIndex(const Key key)
    {
        auto tr    = createTransaction();
        auto value = tr[key];
        tr.commit.await;
        return value;
    }

    RecordRange opIndex(RangeInfo info)
    {
        auto tr    = createTransaction();
        auto value = cast(RecordRange)tr[info];
        tr.commit.await;
        return value;
    }

    inout(Value) opIndexAssign(inout(Value) value, const Key key)
    {
        auto tr = createTransaction();
        tr[key] = value;
        tr.commit.await;
        return value;
    }

    void clear(const Key key)
    {
        auto tr = createTransaction();
        tr.clear(key);
    }

    void clearRange(const RangeInfo info)
    {
        auto tr = createTransaction();
        tr.clearRange(info);
    }

    void run(SimpleWorkFunc func)
    {
        auto tr = createTransaction();
        tr.run(func);
    };

    alias LoopFuture = shared FunctionFuture!(
        retryLoop, ParameterTypeTuple!retryLoop);

    LoopFuture doTransaction(
        WorkFunc           func,
        VoidFutureCallback commitCallback)
    {
        auto tr = createTransaction();
        return tr.doTransaction(func, commitCallback);
    };
}
