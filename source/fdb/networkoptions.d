module fdb.networkoptions;

import
    std.conv,
    std.exception,
    std.string;

import
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options;

class NetworkOptions
{
    static void init()
    {
        setNetworkOption(NetworkOption.NONE);
    }

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
    static void setTraceEnable(in string value)
    {
        setNetworkOption(NetworkOption.TRACE_ENABLE, value);
    }

    /* Set internal tuning or debugging knobs
     * Parameter: (String) knob_name=knob_value
     */
    static void setKnob(in string value)
    {
        setNetworkOption(NetworkOption.KNOB, value);
    }

    /* Set the TLS plugin to load. This option, if used, must be set before any
     * other TLS options
     * Parameter: (String) file path or linker-resolved name
     */
    static void setTlsPlugin(in string value)
    {
        setNetworkOption(NetworkOption.TLS_PLUGIN, value);
    }

    /* Set the certificate chain
     * Parameter: (Bytes) certificates
     */
    static void setTlsCertBytes(in ubyte[] value)
    {
        setNetworkOption(NetworkOption.TLS_CERT_BYTES, value);
    }

    /* Set the file from which to load the certificate chain
     * Parameter: (String) file path
     */
    static void setTlsCertPath(in string value)
    {
        setNetworkOption(NetworkOption.TLS_CERT_PATH, value);
    }

    /* Set the private key corresponding to your own certificate
     * Parameter: (Bytes) key
     */
    static void setTlsKeyBytes(in ubyte[] value)
    {
        setNetworkOption(NetworkOption.TLS_KEY_BYTES, value);
    }

    /* Set the file from which to load the private key corresponding to your own
     * certificate
     * Parameter: (String) file path
     */
    static void setTlsKeyPath(in string value)
    {
        setNetworkOption(NetworkOption.TLS_KEY_PATH, value);
    }

    /* Set the peer certificate field verification criteria
     * Parameter: (Bytes) verification pattern
     */
    static void setTlsVerifyPeers(in ubyte[] value) {
        setNetworkOption(NetworkOption.TLS_VERIFY_PEERS, value);
    }

    private static void setNetworkOption(in NetworkOption op)
    {
        enforceError(fdb_network_set_option(op, null, 0));
    }

    private static void setNetworkOption(in NetworkOption op, in ubyte[] value)
    {
        const auto err = fdb_network_set_option(
            op,
            cast(immutable(char)*)value,
            cast(int)value.length);
        enforceError(err);
    }

    private static void setNetworkOption(in NetworkOption op, in string value)
    {
        const auto err = fdb_network_set_option(
            op,
            value.toStringz,
            cast(int)value.length);
        enforceError(err);
    }
};
