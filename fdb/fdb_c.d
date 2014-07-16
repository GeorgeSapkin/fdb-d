module fdb.fdb_c;

import
    fdb.fdb_c_options;

immutable uint FDB_API_VERSION = 200;

struct FDBCluster {}
alias ClusterHandle     = FDBCluster *;

struct FDBDatabase {}
alias DatabaseHandle    = FDBDatabase *;

struct FDBFuture {}
alias FutureHandle      = FDBFuture *;

struct FDBTransaction {}
alias TransactionHandle = FDBTransaction *;

alias fdb_error_t       = int;
alias fdb_bool_t        = int;

alias Key               = ubyte[];
alias Value             = ubyte[];

struct keyvalue
{
    align (4):
        void * key;
        int    key_length;
        void * value;
        int    value_length;
}
alias FDBKeyValue = keyvalue;

fdb_error_t     fdb_select_api_version(int runtime_version)
{
    return fdb_select_api_version_impl(runtime_version, FDB_API_VERSION);
}

////////////////////// functions implemented in libfdb_c ///////////////////////
extern (C):

alias FDBCallback = void function(
    FDBFuture *         future,
    void *              callback_parameter);

char *          fdb_get_error(
    fdb_error_t code);

fdb_error_t     fdb_network_set_option(
    const NetworkOption option,
    immutable char *    value,
    int                 value_length);

fdb_error_t     fdb_setup_network();

fdb_error_t     fdb_run_network();

fdb_error_t     fdb_stop_network();

void            fdb_future_cancel(
    FDBFuture *         f);

void            fdb_future_release_memory(
    FDBFuture *         f);

void            fdb_future_destroy(
    FDBFuture *         f);

fdb_error_t     fdb_future_block_until_ready(
    const FDBFuture *   f);

fdb_bool_t      fdb_future_is_ready(
    FDBFuture *         f);

fdb_error_t     fdb_future_set_callback(
    FDBFuture *         f,
    FDBCallback         callback,
    void *              callback_parameter);

fdb_error_t     fdb_future_get_error(
    FDBFuture *         f);

fdb_error_t     fdb_future_get_version(
    FDBFuture *         f,
    long *              out_version);

fdb_error_t     fdb_future_get_key(
    FDBFuture *         f,
    ubyte **            out_key,
    int *               out_key_length);

fdb_error_t     fdb_future_get_cluster(
    const FDBFuture *   f,
    FDBCluster **       out_cluster);

fdb_error_t     fdb_future_get_database(
    FDBFuture *         f,
    FDBDatabase **      out_database);

fdb_error_t     fdb_future_get_value(
    FDBFuture *         f,
    fdb_bool_t *        out_present,
    ubyte **            out_value,
    int *               out_value_length);

fdb_error_t     fdb_future_get_keyvalue_array(
    FDBFuture *         f,
    keyvalue **         out_kv,
    int *               out_count,
    fdb_bool_t *        out_more);

fdb_error_t     fdb_future_get_string_array(
    FDBFuture *         f,
    char ***            out_strings,
    int *               out_count);

FDBFuture *     fdb_create_cluster(
    immutable(char) *   cluster_file_path);

void            fdb_cluster_destroy(
    const FDBCluster *  c);

fdb_error_t     fdb_cluster_set_option(
    const FDBCluster *  c,
    ClusterOption       option,
    immutable char *    value,
    int                 value_length);

FDBFuture *     fdb_cluster_create_database(
    const FDBCluster *  c,
    immutable char *    db_name,
    int                 db_name_length);

void            fdb_database_destroy(
    const FDBDatabase * d);

fdb_error_t     fdb_database_set_option(
    const FDBDatabase *     d,
    const DatabaseOption    option,
    immutable char *        value,
    int                     value_length);

fdb_error_t     fdb_database_create_transaction(
    const FDBDatabase * d,
    FDBTransaction **   out_transaction);

void            fdb_transaction_destroy(
    const(FDBTransaction *) tr);

void            fdb_transaction_cancel(
    const(FDBTransaction *) tr);

fdb_error_t     fdb_transaction_set_option(
    const(FDBTransaction *) tr,
    TransactionOption   option,
    immutable(char) *   value,
    int                 value_length);

void            fdb_transaction_set_read_version(
    const(FDBTransaction *) tr,
    long                versionNumber);

FDBFuture *     fdb_transaction_get_read_version(
    const(FDBTransaction *) tr);

FDBFuture *     fdb_transaction_get(
    const(FDBTransaction *) tr,
    ubyte *             key_name,
    int                 key_name_length,
    fdb_bool_t          snapshot);

FDBFuture *     fdb_transaction_get_key(
    const FDBTransaction * tr,
    const ubyte *       key_name,
    const int           key_name_length,
    const fdb_bool_t    or_equal,
    const int           offset,
    const fdb_bool_t    snapshot);

FDBFuture *     fdb_transaction_get_addresses_for_key(
    const(FDBTransaction *) tr,
    ubyte *             key_name,
    int                 key_name_length);

FDBFuture *     fdb_transaction_get_range(
    const(FDBTransaction *) tr,
    const ubyte *           begin_key_name,
    const int               begin_key_name_length,
    const fdb_bool_t        begin_or_equal,
    const int               begin_offset,
    const ubyte *           end_key_name,
    const int               end_key_name_length,
    const fdb_bool_t        end_or_equal,
    const int               end_offset,
    const int               limit,
    const int               target_bytes,
    const StreamingMode     mode,
    const int               iteration,
    const fdb_bool_t        snapshot,
    const fdb_bool_t        reverse);

void            fdb_transaction_set(
    const FDBTransaction * tr,
    const ubyte *       key_name,
    const int           key_name_length,
    const ubyte *       value,
    const int           value_length);

void            fdb_transaction_atomic_op(
    const(FDBTransaction *) tr,
    ubyte *             key_name,
    int                 key_name_length,
    ubyte *             param,
    int                 param_length,
    MutationType        operation_type);

void            fdb_transaction_clear(
    const(FDBTransaction *) tr,
    ubyte *             key_name,
    int                 key_name_length);

void            fdb_transaction_clear_range(
    const(FDBTransaction *) tr,
    ubyte *             begin_key_name,
    int                 begin_key_name_length,
    ubyte *             end_key_name,
    int                 end_key_name_length);

FDBFuture *     fdb_transaction_watch(
    const(FDBTransaction *) tr,
    ubyte *             key_name,
    int                 key_name_length);

FDBFuture *     fdb_transaction_commit(
    const(FDBTransaction *) tr);

fdb_error_t     fdb_transaction_get_committed_version(
    const(FDBTransaction *) tr,
    long *              out_version);

FDBFuture *     fdb_transaction_on_error(
    const(FDBTransaction *) tr,
    fdb_error_t         error);

void            fdb_transaction_reset(
    const(FDBTransaction *) tr);

fdb_error_t     fdb_transaction_add_conflict_range(
    const(FDBTransaction *) tr,
    ubyte *             begin_key_name,
    int                 begin_key_name_length,
    ubyte *             end_key_name,
    int                 end_key_name_length,
    ConflictRangeType   type);

fdb_error_t     fdb_select_api_version_impl(
    int                 runtime_version,
    int                 header_version);

int             fdb_get_max_api_version();
