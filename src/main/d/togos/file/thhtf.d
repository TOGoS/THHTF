module togos.file.thhtf;

import togos.debugutil : logDebug;
import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import std.string : format;
import core.sys.posix.sys.types : off_t;
import togos.file.mmapped : MMapped;

struct Entry {
    off_t offset;
    ubyte[] key;
    ubyte[] value;
}

class THHTFFile {
    const string filename;
    const size_t keySize, valueSize;
    const int rowLength, slop;
    const ubyte[] emptyKey;
    MMapped fayal;
    
    this(string filename, MMapped fayal, size_t keySize, size_t valueSize, int rowLength, int slop ) {
        assert(rowLength > 0);
        assert(slop == 0); // Nonzero slop not yet implemented
        this.filename = filename;
        this.fayal = fayal;
        this.keySize = keySize;
        this.valueSize = valueSize;
        this.rowLength = rowLength;
        this.slop = slop;
        this.emptyKey = new ubyte[keySize];
    }
    
    static string generateFilename(string basename, size_t keySize, size_t valueSize, int rowLength, int slop) {
        if( slop == 0 ) {
            return format("%s.%d-%d-%d.thht", basename, keySize, valueSize, rowLength);
        } else {
            return format("%s.%d-%d-%d-%d.thht", basename, keySize, valueSize, rowLength, slop);
        }
    }
    
    static THHTFFile open(string basename, size_t keySize, size_t valueSize, int rowLength, int slop, bool writable) {
        string filename = generateFilename(basename, keySize, valueSize, rowLength, slop);
        MMapped f = MMapped.open(filename, writable);
        return new this(filename, f, keySize, valueSize, rowLength, slop);
    }
    
    @property size_t entrySize() { return keySize + valueSize; }
    @property size_t rowSize() { return entrySize * rowLength; }
    
    uint column(ubyte[] key) {
        uint c = cast(uint)(
            (key[key.length-1]<< 0) |
            (key[key.length-2]<< 8) |
            (key[key.length-3]<<16) |
            (key[key.length-4]<<24)
        ) % this.rowLength;
        return c;
    }
    
    off_t find( ubyte[] key, int column ) {
        assert(key.length == keySize);
        off_t i = column * entrySize;
        while( i + entrySize <= fayal.size ) {
            ubyte *data = cast(ubyte*)fayal.at(i);
            if( data[0..keySize] == key ) {
                return i;
            }
            i += rowSize;
        }
        return -1;
    }
    
    Entry find( ubyte[] key ) {
        off_t i = find( key, column(key) );
        if( i < 0 ) return Entry(-1, null, null);
        
        ubyte *data = cast(ubyte*)fayal.at(i);
        ubyte[] keyCopy = new ubyte[keySize];
        ubyte[] valCopy = new ubyte[valueSize];
        keyCopy[0..keySize] = key;
        valCopy[0..valueSize] = data[keySize..keySize+valueSize];
        return Entry(i, keyCopy, valCopy);
    }
    
    void put( ubyte[] key, ubyte[] value ) {
        assert(key.length == keySize);
        assert(value.length == valueSize);
        off_t i = column(key) * entrySize;
        while( i + entrySize <= fayal.size ) {
            ubyte *place = cast(ubyte*)fayal.at(i);
            if( place[0..keySize] == key ) break;
            i += rowSize;
        }
        fayal.put(i, key ~ value);
    }
    
    ubyte[] get( ubyte[] key ) {
        Entry e = find(key);
        return e.offset == -1 ? null : e.value;
    }
    
    void close() {
        fayal.close();
    }
}

unittest {
    import std.algorithm : fill;
    import std.ascii : letters;
    import std.conv : to;
    import std.file : remove;
    import std.random : randomCover, rndGen;
    
    string randomString(int length) {
        dchar[] str = new dchar[length];
        fill(str, randomCover(to!(dchar[])(letters), rndGen));
        return to!(string)(str);
    }

    string basename = ".temp" ~ randomString(10);
    THHTFFile tf = THHTFFile.open(basename, 4, 1, 4, 0, true);
    tf.put([1,2,3,4], [ 7]);
    tf.put([5,2,3,4], [12]);
    tf.put([1,2,3,4], [ 8]);
    tf.put([1,2,3,5], [ 9]);
    assert(cast(ubyte[])[ 9] == tf.get([1,2,3,5]));
    assert(cast(ubyte[])[ 8] == tf.get([1,2,3,4]));
    assert(cast(ubyte[])[12] == tf.get([5,2,3,4]));
    
    remove(tf.filename);
}

struct BlobOffsetRef {
    const static uint FLAG_TRUE  = 0x1;
    const static uint FLAG_FALSE = 0x2;
    const static uint FLAG_RAW_AT_OFFSET = 0x4;
    const static uint FLAG_DEFLATED_AT_OFFSET = 0x5;
    
    /**
     * nybble usage:
     * fssssooooooooooo
     * |\__/\_________/
     * |  |  |
     * |  |  +- offset (44 bits)
     * |  +--- size (16 bits)
     * +--- flags (4 bits)
     */
    ulong data;
    
    @property uint flags() {
        return (data >>> 60) & 0xF;
    }
    @property size_t blobSize() {
        return (data >>> 44) & 0xFFFF;
    }
    @property off_t blobOffset() {
        return data & 0xFFFFFFFFFFF;
    }
    @property ubyte[8] encoded() {
        return nativeToBigEndian(data);
    }
    
    static BlobOffsetRef encode(ulong offset, uint size, uint flags) {
        return BlobOffsetRef(
            (cast(ulong)(flags & 0xF) << 60) |
            (cast(ulong)(size & 0xFF) << 44) |
            (offset & 0xFFFFFFFFFFF) );
    }
    
    static BlobOffsetRef decode(ubyte[8] data) {
        return BlobOffsetRef(bigEndianToNative!ulong(data));
    }
}

class THHTFBlobStore {
    MMapped blobs;
    THHTFFile index;
    
    this( MMapped blobs, THHTFFile index ) {
        this.blobs = blobs;
        this.index = index;
    }
    
    ubyte[] get(ubyte[] key) {
        ubyte[] refBytes = index.get(key);
        if( refBytes == null ) return null;
        BlobOffsetRef bor = BlobOffsetRef.decode(refBytes[0..8]);
        return blobs[bor.blobOffset..bor.blobOffset+bor.blobSize];
    }
    
    void put(ubyte[] key, ubyte[] value) {
        off_t offset = blobs.size;
        size_t size = value.length;
        logDebug(format("Putting blob at %d",offset));
        blobs[offset..offset+size] = value;
        logDebug("Blob put.");
        BlobOffsetRef bor = BlobOffsetRef.encode(offset, size, BlobOffsetRef.FLAG_RAW_AT_OFFSET);
        logDebug("Updating index...");
        index.put(key, bor.encoded);
        logDebug("Index updated");
    }
    
    void close() {
        blobs.close();
        index.close();
    }
}

unittest {
    import std.algorithm : fill;
    import std.ascii : letters;
    import std.conv : to;
    import std.random : randomCover, rndGen, uniform;
    import core.sys.posix.unistd : unlink;
    
    ubyte[] randomByteString(int length) {
        ubyte[] str = new ubyte[length];
        for( int i=0; i<length; ++i ) {
            str[i] = cast(ubyte)uniform(0,256);
        }
        return str;
    }
    string randomString(int length) {
        dchar[] str = new dchar[length];
        fill(str, randomCover(to!(dchar[])(letters), rndGen));
        return to!(string)(str);
    }
    
    int keyLength = 20;
    
    string basename = ".temp-" ~ randomString(10);
    THHTFBlobStore bs = new THHTFBlobStore(
        MMapped.open(basename~".dat", true),
        THHTFFile.open(basename, keyLength, 8, 8, 0, true)
    );
    
    struct TestPair {
        ubyte[] key;
        ubyte[] value;
    }
    TestPair[] testPairs = new TestPair[20];;
    for( int i=0; i<testPairs.length; ++i ) {
        testPairs[i] = TestPair( randomByteString(keyLength), randomByteString(uniform(0,65536,rndGen)) );
    }
    for( int i=0; i<testPairs.length; ++i ) {
        bs.put( testPairs[i].key, testPairs[i].value );
    }
    // Crash happens here ^
    for( int i=0; i<testPairs.length; ++i ) {
        assert( testPairs[i].value == bs.get(testPairs[i].key) );
    }    
}
