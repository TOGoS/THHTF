#!/usr/bin/env rdmd

import std.conv : to;
import std.string : format;
import core.sys.posix.unistd : write;
import core.sys.posix.sys.types : off_t;
import togos.file.mmapped : MMapped;

void logDebug(string str) {
    byte[] b = cast(byte[])(str ~ "\n");
    write(1, cast(byte*)b, b.length);
}

struct Entry {
    off_t offset;
    byte[] key;
    byte[] value;
}

class THHTFFile {
    MMapped fayal;
    const size_t keySize, valueSize;
    const int rowLength, slop;
    const byte[] emptyKey;
    
    this(MMapped fayal, size_t keySize, size_t valueSize, int rowLength, int slop ) {
        assert(rowLength > 0);
        this.fayal = fayal;
        this.keySize = keySize;
        this.valueSize = valueSize;
        this.rowLength = rowLength;
        this.slop = slop;
        this.emptyKey = new byte[keySize];
    }
    
    static string filename(string basename, size_t keySize, size_t valueSize, int rowLength, int slop) {
        if( slop == 0 ) {
            return format("%s.%d-%d-%d.thht", basename, keySize, valueSize, rowLength);
        } else {
            return format("%s.%d-%d-%d-%d.thht", basename, keySize, valueSize, rowLength, slop);
        }
    }
    
    static THHTFFile open(string basename, size_t keySize, size_t valueSize, int rowLength, int slop, bool writable) {
        MMapped f = MMapped.open(filename(basename, keySize, valueSize, rowLength, slop), writable);
        return new this(f, keySize, valueSize, rowLength, slop);
    }
    
    @property size_t entrySize() { return keySize + valueSize; }
    @property size_t rowSize() { return entrySize * rowLength; }
    
    int column(byte[] key) {
        int c = (
            (key[key.length-1]<< 0) |
            (key[key.length-2]<< 8) |
            (key[key.length-3]<<16) |
            (key[key.length-4]<<24)
        ) % this.rowLength;
        return c;
    }
    
    off_t find( byte[] key, int column ) {
        assert(key.length == keySize);
        off_t i = column * entrySize;
        while( i + entrySize <= fayal.size ) {
            byte *data = cast(byte*)fayal.at(i);
            if( data[0..keySize] == key ) {
                return i;
            }
            i += rowSize;
        }
        return -1;
    }
    
    Entry find( byte[] key ) {
        off_t i = find( key, column(key) );
        if( i < 0 ) return Entry(-1, null, null);
        
        byte *data = cast(byte*)fayal.at(i);
        byte[] keyCopy = new byte[keySize];
        byte[] valCopy = new byte[valueSize];
        keyCopy[0..keySize] = key;
        valCopy[0..valueSize] = data[keySize..keySize+valueSize];
        return Entry(i, keyCopy, valCopy);
    }
    
    void put( byte[] key, byte[] value ) {
        assert(key.length == keySize);
        assert(value.length == valueSize);
        off_t i = column(key) * entrySize;
        while( i + entrySize <= fayal.size ) {
            byte *place = cast(byte*)fayal.at(i);
            if( place[0..keySize] == key ) break;
            i += rowSize;
        }
        fayal.put(i, key ~ value);
    }
    
    byte[] get( byte[] key ) {
        Entry e = find(key);
        return e.offset == -1 ? null : e.value;
    }
}

void write( int fh, string s ) {
    write(fh, cast(byte *)s, s.length);
}

/** Make sure array comparisons work like I expect */
unittest {
    byte[] a = new byte[3];
    a[1] = 100;
    byte[] b = a[0..2];
    assert((cast(byte*)a)[0..2] == b);
}

unittest {
    import std.algorithm : fill;
    import std.ascii : letters;
    import std.conv : to;
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
    assert(cast(byte[])[ 9] == tf.get([1,2,3,5]));
    assert(cast(byte[])[ 8] == tf.get([1,2,3,4]));
    assert(cast(byte[])[12] == tf.get([5,2,3,4]));
}

void main() {
    /*
    Entry e = Entry( cast(byte[])"abc", cast(byte[])"def" );
    MMapped raf = MMapped.open("blah.dat", true);
    write(0, format("File size: %d\n", raf.size));
    raf.put(raf.size, cast(byte[])"WHAT");
    byte[] data = raf.get(raf.size-4, 4);
    write(0, format("Got some data! %s\n", cast(string)data));
    */
}
