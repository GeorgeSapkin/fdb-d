import std.stdio;

import fdb;

void main() {
    selectAPIVersion(23);
    startNetwork();
    auto cluster = createCluster("zomg");
    auto db = cluster.openDatabase("tehDB");
    auto tr = db.createTransaction();
}