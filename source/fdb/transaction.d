module fdb.transaction;

import
    std.array,
    std.conv,
    std.exception,
    std.string;

import
    fdb.context,
    fdb.database,
    fdb.disposable,
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.future,
    fdb.range,
    fdb.rangeinfo;

shared interface IReadOnlyTransaction
{
    @property bool isSnapshot();

    shared(Key) getKey(in Selector selector);
    shared(KeyFuture) getKeyAsync(
        in Selector       selector,
        KeyFutureCallback callback = null);

    shared(Value) get(in Key key);
    shared(ValueFuture) getAsync(
        in Key              key,
        ValueFutureCallback callback = null);

    /**
     * Returns: Key-value pairs within (begin, end) range
     */
    RecordRange getRange(RangeInfo info);
    /// ditto
    shared(KeyValueFuture) getRangeAsync(
        RangeInfo              info,
        KeyValueFutureCallback callback = null);

    void addReadConflictRange(RangeInfo info);
    void addWriteConflictRange(RangeInfo info);

    void onError(in FDBException ex);
    shared(VoidFuture) onErrorAsync(
        in FDBException    ex,
        VoidFutureCallback callback = null);

    ulong getReadVersion();
    shared(VersionFuture) getReadVersionAsync(
        VersionFutureCallback callback = null);

    long getCommittedVersion();

    shared(string[]) getAddressesForKey(in Key key);
    shared(StringFuture) getAddressesForKeyAsync(
        in Key               key,
        StringFutureCallback callback = null);

    shared(Value) opIndex(in Key key);

    RecordRange opIndex(RangeInfo info);
}

alias WorkFunc = void delegate(shared Transaction tr, VoidFutureCallback cb);

shared class Transaction : IDatabaseContext, IDisposable, IReadOnlyTransaction
{
    private const Database    db;
    private TransactionHandle th;

    private const bool _isSnapshot;
    @property bool isSnapshot()
    {
        return _isSnapshot;
    }

    private IDisposable[] futures;

    invariant()
    {
        assert(db !is null);
    }

    this(TransactionHandle th, in shared Database db)
    in
    {
        enforce(db !is null, "db must be set");
        enforce(th !is null, "th must be set");
    }
    body
    {
        this.th          = cast(shared)th;
        this.db          = db;
        this._isSnapshot = false;
    }

    invariant()
    {
        assert(db !is null);
    }

    private this(
        shared TransactionHandle th,
        in shared Database       db,
        in bool                  isSnapshot)
    in
    {
        enforce(db !is null, "db must be set");
        enforce(th !is null, "th must be set");
    }
    body
    {
        this.th          = cast(shared)th;
        this.db          = db;
        this._isSnapshot = isSnapshot;
    }

    @property shared(IReadOnlyTransaction) snapshot()
    {
        auto snapshot = new shared Transaction(th, db, true);
        return cast(shared IReadOnlyTransaction)snapshot;
    }

    ~this()
    {
        dispose;
    }

    void dispose()
    {
        // parent transaction should handle destruction
        if (!th || isSnapshot) return;

        fdb_transaction_destroy(cast(TransactionHandle)th);
        th = null;
    }

    void set(in Key key, in Value value) const
    in
    {
        enforce(key !is null);
        enforce(!key.empty);
        enforce(value !is null);
        enforce(!value.empty);
    }
    body
    {
        fdb_transaction_set(
            cast(TransactionHandle)th,
            &key[0],
            cast(int)key.length,
            &value[0],
            cast(int)value.length);
    }

    auto commit(VoidFutureCallback callback = null)
    {
        // cancel, commit and reset are mutually exclusive
        synchronized (this)
        {
            auto fh      = fdb_transaction_commit(cast(TransactionHandle)th);
            auto future  = startOrCreateFuture!VoidFuture(fh, this, callback);
            futures     ~= future;
            return future;
        }
    }

    void cancel()
    {
        // cancel, commit and reset are mutually exclusive
        synchronized (this)
            fdb_transaction_cancel(cast(TransactionHandle)th);
    }

    /**
     * Resets transaction to its initial state
     */
    void reset()
    {
        // cancel, commit and reset are mutually exclusive
        synchronized (this)
            fdb_transaction_reset(cast(TransactionHandle)th);
    }

    void clear(in Key key) const
    in
    {
        enforce(key !is null);
        enforce(!key.empty);
    }
    body
    {
        fdb_transaction_clear(
            cast(TransactionHandle)th,
            &key[0],
            cast(int)key.length);
    }

    void clearRange(in RangeInfo info) const
    in
    {
        enforce(!info.begin.key.empty);
        enforce(!info.end.key.empty);
    }
    body
    {
        fdb_transaction_clear_range(
            cast(TransactionHandle)th,
            &info.begin.key[0],
            cast(int)info.begin.key.length,
            &info.end.key[0],
            cast(int)info.end.key.length);
    }

    shared(Key) getKey(in Selector selector)
    {
        auto fh = fdb_transaction_get_key(
            cast(TransactionHandle)th,
            &selector.key[0],
            cast(int)selector.key.length,
            cast(fdb_bool_t)selector.orEqual,
            selector.offset,
            cast(fdb_bool_t)_isSnapshot);

        scope auto future = createFuture!KeyFuture(fh, this);

        auto value = future.await;
        return value;
    }

    shared(KeyFuture) getKeyAsync(
        in Selector       selector,
        KeyFutureCallback callback = null)
    {
        auto fh = fdb_transaction_get_key(
            cast(TransactionHandle)th,
            &selector.key[0],
            cast(int)selector.key.length,
            cast(fdb_bool_t)selector.orEqual,
            selector.offset,
            cast(fdb_bool_t)_isSnapshot);

        auto future = startOrCreateFuture!KeyFuture(fh, this, callback);
        synchronized (this)
            futures ~= future;
        return future;
    }

    shared(Value) get(in Key key)
    in
    {
        enforce(key !is null);
        enforce(!key.empty);
    }
    body
    {
        auto fh = fdb_transaction_get(
            cast(TransactionHandle)th,
            &key[0],
            cast(int)key.length,
            cast(fdb_bool_t)_isSnapshot);

        scope auto future = createFuture!ValueFuture(fh, this);

        auto value = future.await;
        return value;
    }

    shared(ValueFuture) getAsync(in Key key, ValueFutureCallback callback = null)
    in
    {
        enforce(key !is null);
        enforce(!key.empty);
    }
    body
    {
        auto fh = fdb_transaction_get(
            cast(TransactionHandle)th,
            &key[0],
            cast(int)key.length,
            cast(fdb_bool_t)_isSnapshot);

        auto future = startOrCreateFuture!ValueFuture(fh, this, callback);
        synchronized (this)
            futures ~= future;
        return future;
    }

    /**
     * Returns: Key-value pairs within (begin, end) range
     */
    RecordRange getRange(RangeInfo info)
    {
        auto begin = sanitizeKey(info.begin.key, [ 0x00 ]);
        auto end   = sanitizeKey(info.end.key, [ 0xff ]);

        auto fh = fdb_transaction_get_range(
            cast(TransactionHandle)cast(TransactionHandle)th,

            &begin[0],
            cast(int)begin.length,
            cast(fdb_bool_t)info.begin.orEqual,
            info.begin.offset,

            &end[0],
            cast(int)end.length,
            cast(fdb_bool_t)info.end.orEqual,
            info.end.offset,

            info.limit,
            0,
            info.mode,
            info.iteration,
            cast(fdb_bool_t)_isSnapshot,
            info.reverse);

        scope auto future = createFuture!KeyValueFuture(fh, this, info);

        auto value = cast(RecordRange)future.await;
        return value;
    }

    /**
     * Returns: Key-value pairs within (begin, end) range
     */
    shared(KeyValueFuture) getRangeAsync(
        RangeInfo              info,
        KeyValueFutureCallback callback = null)
    {
        auto begin = sanitizeKey(info.begin.key, [ 0x00 ]);
        auto end   = sanitizeKey(info.end.key, [ 0xff ]);

        auto fh = fdb_transaction_get_range(
            cast(TransactionHandle)cast(TransactionHandle)th,

            &begin[0],
            cast(int)begin.length,
            cast(fdb_bool_t)info.begin.orEqual,
            info.begin.offset,

            &end[0],
            cast(int)end.length,
            cast(fdb_bool_t)info.end.orEqual,
            info.end.offset,

            info.limit,
            0,
            info.mode,
            info.iteration,
            cast(fdb_bool_t)_isSnapshot,
            info.reverse);

        auto future = startOrCreateFuture!KeyValueFuture(
            fh, this, info, callback);
        synchronized (this)
            futures ~= future;
        return future;
    }

    auto watch(in Key key, VoidFutureCallback callback = null)
    in
    {
        enforce(key !is null);
        enforce(!key.empty);
    }
    body
    {
        auto fh = fdb_transaction_watch(
            cast(TransactionHandle)th,
            &key[0],
            cast(int)key.length);
        auto future = startOrCreateFuture!WatchFuture(fh, this, callback);
        synchronized (this)
            futures ~= future;
        return future;
    }

    private void addConflictRange(
        RangeInfo            info,
        in ConflictRangeType type) const
    in
    {
        enforce(!info.begin.key.empty);
        enforce(!info.end.key.empty);
    }
    body
    {
        auto err = fdb_transaction_add_conflict_range(
            cast(TransactionHandle)th,
            &info.begin.key[0],
            cast(int)info.begin.key.length,
            &info.end.key[0],
            cast(int)info.end.key.length,
            type);
        enforceError(err);
    }

    void addReadConflictRange(RangeInfo info) const
    {
        addConflictRange(info, ConflictRangeType.READ);
    }

    void addWriteConflictRange(RangeInfo info) const
    {
        addConflictRange(info, ConflictRangeType.WRITE);
    }

    void onError(in FDBException ex)
    {
        auto fh = fdb_transaction_on_error(
            cast(TransactionHandle)th,
            ex.err);

        scope auto future = createFuture!VoidFuture(fh, this);
        future.await;
    }

    shared(VoidFuture) onErrorAsync(
        in FDBException    ex,
        VoidFutureCallback callback = null)
    {
        auto fh = fdb_transaction_on_error(
            cast(TransactionHandle)th,
            ex.err);
        auto future = startOrCreateFuture!VoidFuture(fh, this, callback);
        synchronized (this)
            futures ~= future;
        return future;
    }

    void setReadVersion(in int ver) const
    in
    {
        enforce(ver > 0);
    }
    body
    {
        fdb_transaction_set_read_version(
            cast(TransactionHandle)th,
            ver);
    }

    ulong getReadVersion()
    {
        auto fh = fdb_transaction_get_read_version(
            cast(TransactionHandle)th);

        scope auto future = createFuture!VersionFuture(fh, this);

        auto value = future.await;
        return value;
    }

    shared(VersionFuture) getReadVersionAsync(VersionFutureCallback callback = null)
    {
        auto fh = fdb_transaction_get_read_version(
            cast(TransactionHandle)th);
        auto future = startOrCreateFuture!VersionFuture(fh, this, callback);
        synchronized (this)
            futures ~= future;
        return future;
    }

    long getCommittedVersion() const
    {
        long ver;
        auto err = fdb_transaction_get_committed_version(
            cast(TransactionHandle)th,
            &ver);
        enforceError(err);
        return ver;
    }

    shared(string[]) getAddressesForKey(in Key key)
    in
    {
        enforce(key !is null);
        enforce(!key.empty);
    }
    body
    {
        auto fh = fdb_transaction_get_addresses_for_key(
            cast(TransactionHandle)th,
            &key[0],
            cast(int)key.length);

        scope auto future = createFuture!StringFuture(fh, this);

        auto value = future.await;
        return value;
    }

    shared(StringFuture) getAddressesForKeyAsync(
        in Key               key,
        StringFutureCallback callback = null)
    in
    {
        enforce(key !is null);
        enforce(!key.empty);
    }
    body
    {
        auto fh = fdb_transaction_get_addresses_for_key(
            cast(TransactionHandle)th,
            &key[0],
            cast(int)key.length);

        auto future = startOrCreateFuture!StringFuture(fh, this, callback);
        synchronized (this)
            futures ~= future;
        return future;
    }

    /**
     * Performs an addition of little-endian integers. If the existing value
     * in the database is not present or shorter than ``param``, it is first
     * extended to the length of ``param`` with zero bytes.  If ``param`` is
     * shorter than the existing value in the database, the existing value is
     * truncated to match the length of ``param``. The integers to be added
     * must be stored in a little-endian representation.  They can be signed
     * in two's complement representation or unsigned. You can add to an integer
     * at a known offset in the value by prepending the appropriate number of
     * zero bytes to ``param`` and padding with zero bytes to match the length
     * of the value. However, this offset technique requires that you know the
     * addition will not cause the integer field within the value to overflow.
     */
    void add(in Key key, in Value value) const
    {
        callAtomicOperation(key, value, MutationType.ADD);
    }

    /**
     * Performs a bitwise ``and`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    void bitAnd(in Key key, in Value value) const
    {
        callAtomicOperation(key, value, MutationType.BIT_AND);
    }

    /**
     * Performs a bitwise ``or`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    void bitOr(in Key key, in Value value) const
    {
        callAtomicOperation(key, value, MutationType.BIT_OR);
    }

    /**
     * Performs a bitwise ``xor`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    void bitXor(in Key key, in Value value) const
    {
        callAtomicOperation(key, value, MutationType.BIT_XOR);
    }

    /**
     * Performs a little-endian comparison of byte strings.
     * If the existing value in the database is not present or shorter than
     * ``param``, it is first extended to the length of ``param`` with zero
     * bytes.
     * If ``param`` is shorter than the existing value in the database, the
     * existing value is truncated to match the length of ``param``.
     * The larger of the two values is then stored in the database.
     */
    void bitMax(in Key key, in Value value) const
    {
        callAtomicOperation(key, value, MutationType.MAX);
    }

    /**
     * Performs a little-endian comparison of byte strings.
     * If the existing value in the database is not present or shorter than
     * ``param``, it is first extended to the length of ``param`` with zero
     * bytes.
     * If ``param`` is shorter than the existing value in the database, the
     * existing value is truncated to match the length of ``param``.
     * The smaller of the two values is then stored in the database.
     */
    void bitMin(in Key key, in Value value) const
    {
        callAtomicOperation(key, value, MutationType.MIN);
    }

    private void callAtomicOperation(
        in Key          key,
        in Value        value,
        in MutationType type) const
    in
    {
        enforce(key !is null);
        enforce(!key.empty);
        enforce(value !is null);
        enforce(!value.empty);
    }
    body
    {
        fdb_transaction_atomic_op(
            cast(TransactionHandle)th,
            &key[0],
            cast(int)key.length,
            &value[0],
            cast(int)value.length,
            type);
    }

    /**
     * The transaction, if not self-conflicting, may be committed a second time
     * after commit succeeds, in the event of a fault
     */
    void setCausalWriteRisky() const
    {
        setTransactionOption(TransactionOption.CAUSAL_WRITE_RISKY);
    }

    /**
     * The read version will be committed, and usually will be the latest
     * committed, but might not be the latest committed in the event of a fault
     * or partition
     */
    void setCausalReadRisky() const
    {
        setTransactionOption(TransactionOption.CAUSAL_READ_RISKY);
    }

    void setCausalReadDisable() const
    {
        setTransactionOption(TransactionOption.CAUSAL_READ_DISABLE);
    }

    /**
     * The next write performed on this transaction will not generate a write
     * conflict range. As a result, other transactions which read the key(s)
     * being modified by the next write will not conflict with this transaction.
     * Care needs to be taken when using this option on a transaction that is
     * shared between multiple threads. When setting this option, write conflict
     * ranges will be disabled on the next write operation, regardless of what
     * thread it is on.
     */
    void setNextWriteNoWriteConflictRange() const
    {
        setTransactionOption(
            TransactionOption.NEXT_WRITE_NO_WRITE_CONFLICT_RANGE);
    }

    void setCheckWritesEnable() const
    {
        setTransactionOption(TransactionOption.CHECK_WRITES_ENABLE);
    }

    /**
     * Reads performed by a transaction will not see any prior mutations that
     * occured in that transaction, instead seeing the value which was in the
     * database at the transaction's read version. This option may provide a
     * small performance benefit for the client, but also disables a number of
     * client-side optimizations which are beneficial for transactions which
     * tend to read and write the same keys within a single transaction.
     */
    void setReadYourWritesDisable() const
    {
        setTransactionOption(TransactionOption.READ_YOUR_WRITES_DISABLE);
    }

    /**
     * Disables read-ahead caching for range reads. Under normal operation, a
     * transaction will read extra rows from the database into cache if range
     * reads are used to page through a series of data one row at a time (i.e.
     * if a range read with a one row limit is followed by another one row range
     * read starting immediately after the result of the first).
     */
    void setReadAheadDisable() const
    {
        setTransactionOption(TransactionOption.READ_AHEAD_DISABLE);
    }

    /**
     * Specifies that this transaction should be treated as highest priority and
     * that lower priority transactions should block behind this one. Use is
     * discouraged outside of low-level tools
     */
    void setPrioritySystemImmediate() const
    {
        setTransactionOption(TransactionOption.PRIORITY_SYSTEM_IMMEDIATE);
    }

    /**
     * Specifies that this transaction should be treated as low priority and
     * that default priority transactions should be processed first. Useful for
     * doing batch work simultaneously with latency-sensitive work
     */
    void setPriorityBatch() const
    {
        setTransactionOption(TransactionOption.PRIORITY_BATCH);
    }

    /**
     * This is a write-only transaction which sets the initial configuration
     */
    void setInitializeNewDatabase() const
    {
        setTransactionOption(TransactionOption.INITIALIZE_NEW_DATABASE);
    }

    /**
     * Allows this transaction to read and modify system keys (those that start
     * with the byte 0xFF)
     */
    void setAccessSystemKeys() const
    {
        setTransactionOption(TransactionOption.ACCESS_SYSTEM_KEYS);
    }

    /**
     * Allows this transaction to read system keys (those that start with the
     * byte 0xFF)
     */
    void setReadSystemKeys() const
    {
        setTransactionOption(TransactionOption.READ_SYSTEM_KEYS);
    }

    void setDebugDump() const
    {
        setTransactionOption(TransactionOption.DEBUG_DUMP);
    }

    /**
     * Params:
     *      transactionName = Optional transaction name
     */
    void setDebugRetryLogging(in string transactionName = null) const
    {
        setTransactionOption(
            TransactionOption.DEBUG_RETRY_LOGGING,
            transactionName);
    }

    /**
     * Set a timeout in milliseconds which, when elapsed, will cause the
     * transaction automatically to be cancelled. Valid parameter values are
     * ``[0, INT_MAX]``. If set to 0, will disable all timeouts. All pending and
     * any future uses of the transaction will throw an exception. The
     * transaction can be used again after it is reset.
     * Params:
     *      value = value in milliseconds of timeout
     */
    void setTimeout(in int value) const
    {
        setTransactionOption(TransactionOption.TIMEOUT, value);
    }

    /**
     * Set a maximum number of retries after which additional calls to onError
     * will throw the most recently seen error code. Valid parameter values are
     * ``[-1, INT_MAX]``. If set to -1, will disable the retry limit.
     * Params:
     *      value = number of times to retry
     */
    void setRetryLimit(in int value) const
    {
        setTransactionOption(TransactionOption.RETRY_LIMIT, value);
    }

    /**
     * Set the maximum amount of backoff delay incurred in the call to onError
     * if the error is retryable.
     * Defaults to 1000 ms. Valid parameter values are [0, int.MaxValue].
     * Like all transaction options, the maximum retry delay must be reset
     * after a call to onError.
     * If the maximum retry delay is less than the current retry delay of the
     * transaction, then the current retry delay will be clamped to the maximum
     * retry delay.
     * Params:
     *      value = value in milliseconds of maximum delay
     */
    void setMaxRetryDelayLimit(in int value) const
    {
        setTransactionOption(TransactionOption.MAX_RETRY_DELAY, value);
    }

    /**
     * Snapshot read operations will see the results of writes done in the same
     * transaction.
     */
    void setSnapshotReadYourWriteEnable() const
    {
        setTransactionOption(TransactionOption.SNAPSHOT_READ_YOUR_WRITE_ENABLE);
    }

    /**
     * Snapshot read operations will not see the results of writes done in the
     * same transaction.
     */
    void setSnapshotReadYourWriteDisable() const
    {
        setTransactionOption(
            TransactionOption.SNAPSHOT_READ_YOUR_WRITE_DISABLE);
    }

    private void setTransactionOption(in TransactionOption op) const
    {
        auto err = fdb_transaction_set_option(
            cast(TransactionHandle)th,
            op,
            null,
            0);
        enforceError(err);
    }

    private void setTransactionOption(
        in TransactionOption op,
        in int               value) const
    {
        auto err = fdb_transaction_set_option(
            cast(TransactionHandle)th,
            op,
            cast(immutable(char)*)&value,
            cast(int)value.sizeof);
        enforceError(err);
    }

    private void setTransactionOption(
        in TransactionOption op,
        in string            value) const
    {
        auto err = fdb_transaction_set_option(
            cast(TransactionHandle)th,
            op,
            value.toStringz,
            cast(int)value.length);
        enforceError(err);
    }

    shared(Value) opIndex(in Key key)
    {
        return get(key);
    }

    RecordRange opIndex(RangeInfo info)
    {
        return getRange(info);
    }

    inout(Value) opIndexAssign(inout(Value) value, in Key key)
    {
        set(key, value);
        return value;
    }

    void run(SimpleWorkFunc func)
    {
        WorkFunc wf = (tr, cb)
        {
            func(tr);
            cb(null);
        };

        shared Exception exception;
        VoidFutureCallback cb = (ex)
        {
            exception = cast(shared)ex;
        };

        auto future = createFuture!retryLoop(this, wf, cb);
        future.await;

        enforce(exception is null, cast(Exception)exception);
    };

    auto doTransaction(WorkFunc func, VoidFutureCallback commitCallback)
    {
        auto future = createFuture!retryLoop(this, func, commitCallback);
        return future;
    };
}

void retryLoop(shared Transaction tr, WorkFunc func, VoidFutureCallback cb)
{
    try
    {
        func(tr, (ex)
        {
            if (ex)
                onError(tr, ex, func, cb);
            else
            {
                auto future = tr.commit((commitErr)
                {
                    if (commitErr)
                        onError(tr, commitErr, func, cb);
                    else
                        cb(commitErr);
                });
                future.await;
            }
        });
    }
    catch (Exception ex)
    {
        onError(tr, ex, func, cb);
    }
}

private void onError(
    shared Transaction tr,
    Exception          ex,
    WorkFunc           func,
    VoidFutureCallback cb)
{
    if (auto fdbex = cast(FDBException)ex)
    {
        tr.onErrorAsync(fdbex, (retryErr)
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
