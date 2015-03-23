module togos.errutil;

import core.stdc.errno : errno;
import core.stdc.string : strerror;
import std.conv : to;

string errstr() {
    return to!string(strerror(errno));
}
