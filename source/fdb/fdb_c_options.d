module fdb.fdb_c_options;

enum NetworkOption : uint
{
    // deprecated
    NONE              = 0,

    // deprecated
    LOCAL_ADDRESS     = 10,

    // deprecated
    CLUSTER_FILE      = 20,

    /**
     * Enables trace output to a file in a directory of the clients choosing
     * Parameter: (String) path to output directory (or NULL for current working
     * directory)
     */
    TRACE_ENABLE      = 30,

    /**
     * Set internal tuning or debugging knobs
     * Parameter: (String) knob_name=knob_value
     */
    KNOB              = 40,

    /**
     * Set the TLS plugin to load. This option, if used, must be set before any
     * other TLS options
     * Parameter: (String) file path or linker-resolved name
     */
    TLS_PLUGIN,

    /**
     * Set the certificate chain
     * Parameter: (Bytes) certificates
     */
    TLS_CERT_BYTES,

    /**
     * Set the file from which to load the certificate chain
     * Parameter: (String) file path
     */
    TLS_CERT_PATH,

    /**
     * Set the private key corresponding to your own certificate
     * Parameter: (Bytes) key
     */
    TLS_KEY_BYTES     = 45,

    /**
     * Set the file from which to load the private key corresponding to your own
     * certificate
     * Parameter: (String) file path
     */
    TLS_KEY_PATH,

    /**
     * Set the peer certificate field verification criteria
     * Parameter: (Bytes) verification pattern
     */
    TLS_VERIFY_PEERS,
}

enum ClusterOption : uint
{
    /**
     * This option is only a placeholder for C compatibility and should not be
     * used
     * Parameter: Option takes no parameter
     */
    DUMMY_DO_NOT_USE = -1,
}

enum DatabaseOption : uint
{
    /**
     * Set the size of the client location cache. Raising this value can boost
     * performance in very large databases where clients access data in a near-
     * random pattern. Defaults to 100000.
     * Parameter: (Int) Max location cache entries
     */
    LOCATION_CACHE_SIZE = 10,

    /**
     * Set the maximum number of watches allowed to be outstanding on a database
     * connection. Increasing this number could result in increased resource
     * usage. Reducing this number will not cancel any outstanding watches.
     * Defaults to 10000 and cannot be larger than 1000000.
     * Parameter: (Int) Max outstanding watches
     */
    MAX_WATCHES         = 20,

    /**
     * Specify the machine ID that was passed to fdbserver processes running on
     * the same machine as this client, for better location-aware load
     * balancing.
     * Parameter: (String) Hexadecimal ID
     */
    MACHINE_ID,

    /**
     * Specify the datacenter ID that was passed to fdbserver processes running
     * in the same datacenter as this client, for better location-aware load
     * balancing.
     * Parameter: (String) Hexadecimal ID
     */
    DATACENTER_ID,
}

enum TransactionOption : uint
{
    /**
     * The transaction, if not self-conflicting, may be committed a second time
     * after commit succeeds, in the event of a fault
     * Parameter: Option takes no parameter
     */
    CAUSAL_WRITE_RISKY                 = 10,

    /**
     * The read version will be committed, and usually will be the latest
     * committed, but might not be the latest committed in the event of a fault
     * or partition
     * Parameter: Option takes no parameter
     */
    CAUSAL_READ_RISKY                  = 20,

    /**
     * Parameter: Option takes no parameter
     */
    CAUSAL_READ_DISABLE,

    /**
     * The next write performed on this transaction will not generate a write
     * conflict range. As a result, other transactions which read the key(s)
     * being modified by the next write will not conflict with this transaction.
     * Care needs to be taken when using this option on a transaction that is
     * shared between multiple threads. When setting this option, write conflict
     * ranges will be disabled on the next write operation, regardless of what
     * thread it is on.
     * Parameter: Option takes no parameter
     */
    NEXT_WRITE_NO_WRITE_CONFLICT_RANGE = 30,

    /**
     * Parameter: Option takes no parameter
     */
    CHECK_WRITES_ENABLE                = 50,

    /**
     * Reads performed by a transaction will not see any prior mutations that
     * occured in that transaction, instead seeing the value which was in the
     * database at the transaction's read version. This option may provide a
     * small performance benefit for the client, but also disables a number of
     * client-side optimizations which are beneficial for transactions which
     * tend to read and write the same keys within a single transaction.
     * Parameter: Option takes no parameter
     */
    READ_YOUR_WRITES_DISABLE,

    /**
     * Disables read-ahead caching for range reads. Under normal operation, a
     * transaction will read extra rows from the database into cache if range
     * reads are used to page through a series of data one row at a time (i.e.
     * if a range read with a one row limit is followed by another one row range
     * read starting immediately after the result of the first).
     * Parameter: Option takes no parameter
     */
    READ_AHEAD_DISABLE,

    /**
     * Parameter: Option takes no parameter
     */
    DURABILITY_DATACENTER              = 110,

    /**
     * Parameter: Option takes no parameter
     */
    DURABILITY_RISKY                   = 120,

    /**
     * Parameter: Option takes no parameter
     */
    DURABILITY_DEV_NULL_IS_WEB_SCALE   = 130,

    /**
     * Specifies that this transaction should be treated as highest priority
     * and that lower priority transactions should block behind this one. Use is
     * discouraged outside of low-level tools
     * Parameter: Option takes no parameter
     */
    PRIORITY_SYSTEM_IMMEDIATE          = 200,

    /**
     * Specifies that this transaction should be treated as low priority and
     * that default priority transactions should be processed first. Useful for
     * doing batch work simultaneously with latency-sensitive work
     * Parameter: Option takes no parameter
     */
    PRIORITY_BATCH,

    /**
     * This is a write-only transaction which sets the initial configuration
     * Parameter: Option takes no parameter
     */
    INITIALIZE_NEW_DATABASE            = 300,

    /**
     * Allows this transaction to read and modify system keys (those that start
     * with the byte 0xFF)
     * Parameter: Option takes no parameter
     */
    ACCESS_SYSTEM_KEYS,

    /**
     * Parameter: Option takes no parameter
     */
    DEBUG_DUMP                         = 400,

    /**
     * Set a timeout in milliseconds which, when elapsed, will cause the
     * transaction automatically to be cancelled. Valid parameter values are
     * ``[0, INT_MAX]``. If set to 0, will disable all timeouts. All pending and
     * any future uses of the transaction will throw an exception. The
     * transaction can be used again after it is reset. Like all transaction
     * options, a timeout must be reset after a call to onError. This behavior
     * allows the user to make the timeout dynamic.
     * Parameter: (Int) value in milliseconds of timeout
     */
    TIMEOUT                            = 500,

    /**
     * Set a maximum number of retries after which additional calls to onError
     * will throw the most recently seen error code. Valid parameter values are
     * ``[-1, INT_MAX]``. If set to -1, will disable the retry limit. Like all
     * transaction options, the retry limit must be reset after a call to
     * onError. This behavior allows the user to make the retry limit dynamic.
     * Parameter: (Int) number of times to retry
     */
    RETRY_LIMIT,
}

enum StreamingMode : int
{
    /**
     * Client intends to consume the entire range and would like it all
     * transferred as early as possible.
     */
    WANT_ALL = -2,

    /**
     * The default. The client doesn't know how much of the range it is likely
     * to used and wants different performance concerns to be balanced. Only a
     * small portion of data is transferred to the client initially (in order to
     * minimize costs if the client doesn't read the entire range), and as the
     * caller iterates over more items in the range larger batches will be
     * transferred in order to minimize latency.
     */
    ITERATOR,

    /**
     * Infrequently used. The client has passed a specific row limit and wants
     * that many rows delivered in a single batch. Because of iterator operation
     * in client drivers make request batches transparent to the user, consider
     * ``WANT_ALL`` StreamingMode instead. A row limit must be specified if this
     * mode is used.
     */
    EXACT,

    /**
     * Infrequently used. Transfer data in batches small enough to not be much
     * more expensive than reading individual rows, to minimize cost if
     * iteration stops early.
     */
    SMALL,

    /**
     * Infrequently used. Transfer data in batches sized in between small and
     * large.
     */
    MEDIUM,

    /**
     * Infrequently used. Transfer data in batches large enough to be, in a
     * high-concurrency environment, nearly as efficient as possible. If the
     * client stops iteration early, some disk and network bandwidth may be
     * wasted. The batch size may still be too small to allow a single client to
     * get high throughput from the database, so if that is what you need
     * consider the SERIAL StreamingMode.
     */
    LARGE,

    /**
     * Transfer data in batches large enough that an individual client can get
     * reasonable read bandwidth from the database. If the client stops
     * iteration early, considerable disk and network bandwidth may be wasted.
     */
    SERIAL,
}

enum MutationType : uint
{
    /**
     * Performs an addition of little-endian integers. If the existing value in
     * the database is not present or shorter than ``param``, it is first
     * extended to the length of ``param`` with zero bytes.  If ``param`` is
     * shorter than the existing value in the database, the existing value is
     * truncated to match the length of ``param``. The integers to be added must
     * be stored in a little-endian representation.  They can be signed in two's
     * complement representation or unsigned. You can add to an integer at a
     * known offset in the value by prepending the appropriate number of zero
     * bytes to ``param`` and padding with zero bytes to match the length of the
     * value. However, this offset technique requires that you know the addition
     * will not cause the integer field within the value to overflow.
     */
    ADD     = 2,

    // deprecated
    AND     = 6,

    /**
     * Performs a bitwise ``and`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    BIT_AND = 6,

    // deprecated
    OR,

    /**
     * Performs a bitwise ``or`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    BIT_OR  = 7,

    // deprecated
    XOR,

    /**
     * Performs a bitwise ``xor`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    BIT_XOR = 8,
}

enum ConflictRangeType : uint
{
    /**
     * Used to add a read conflict range
     */
    READ,

    /**
     * Used to add a write conflict range
     */
    WRITE,
}
