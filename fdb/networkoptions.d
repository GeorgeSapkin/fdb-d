module fdb.networkoptions;

import std.conv,
       std.exception,
       std.string;

import fdb.fdb_c,
       fdb.fdb_c_options,
       fdb.helpers;

class NetworkOptions {
    // Deprecated
    // Parameter: (String) IP:PORT
    //ADD_NET_OPTION("local_address", 10, String);

    // Deprecated
    // Parameter: (String) path to cluster file
    //ADD_NET_OPTION("cluster_file", 20, String);

    /* Enables trace output to a file in a directory of the clients choosing
     * Parameter: (String) path to output directory (or NULL for current working
     * directory)
     */
    static void setTraceEnable(string value) {
        setNetworkOption(NetworkOption.TRACE_ENABLE, value);
    }

    /* Set internal tuning or debugging knobs
     * Parameter: (String) knob_name=knob_value
     */
    static void setKnob(string value) {
        setNetworkOption(NetworkOption.KNOB, value);
    }

    /* Set the TLS plugin to load. This option, if used, must be set before any
     * other TLS options
     * Parameter: (String) file path or linker-resolved name
     */
    static void setTlsPlugin(string value) {
        setNetworkOption(NetworkOption.TLS_PLUGIN, value);
    }

    /* Set the certificate chain
     * Parameter: (Bytes) certificates
     */
    static void setTlsCertBytes(ubyte[] value) {
        setNetworkOption(NetworkOption.TLS_CERT_BYTES, value);
    }

    /* Set the file from which to load the certificate chain
     * Parameter: (String) file path
     */
    static void setTlsCertPath(string value) {
        setNetworkOption(NetworkOption.TLS_CERT_PATH, value);
    }

    /* Set the private key corresponding to your own certificate
     * Parameter: (Bytes) key
     */
    static void setTlsKeyBytes(ubyte[] value) {
        setNetworkOption(NetworkOption.TLS_KEY_BYTES, value);
    }

    /* Set the file from which to load the private key corresponding to your own
     * certificate
     * Parameter: (String) file path
     */
    static void setTlsKeyPath(string value) {
        setNetworkOption(NetworkOption.TLS_KEY_PATH, value);
    }

    /* Set the peer certificate field verification criteria
     * Parameter: (Bytes) verification pattern
     */
    static void setTlsVerifyPeers(ubyte[] value) {
        setNetworkOption(NetworkOption.TLS_VERIFY_PEERS, value);
    }

    private static void setNetworkOption(NetworkOption op, ubyte[] value) {
        fdb_error_t err = fdb_network_set_option(
            op,
            cast(immutable(char)*)value,
            cast(int)value.length);
        enforce(!err, err.message);
    }

    private static void setNetworkOption(NetworkOption op, string value) {
        fdb_error_t err = fdb_network_set_option(
            op,
            value.toStringz,
            cast(int)value.length);
        enforce(!err, err.message);
    }
};