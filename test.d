#!/usr/bin/env rdmd

import std.string : format;
import std.conv : octal;
import std.stdio : writeln;

import core.sys.posix.sys.stat : fstat, stat_t;
import core.sys.posix.sys.mman;
import core.sys.posix.fcntl : fcntl_open = open, O_CREAT;

struct Entry {
    byte[] key;
    byte[] value;
}

class RandomAccessFile {
    int fd;
    off_t fileSize;
    void *begin;
    void *end;
    
    this(int fd, void *begin, void *end) {
        this.fd = fd;
        this.begin = begin;
        this.end = end;
        stat_t theStat;
        if( fstat(fd, &theStat) ) {
            throw new Exception("Failed to fstat.  <TODO: put error message here>");
        }
        this.fileSize = theStat.st_size;
    }
    
    @property off_t size() { return fileSize; }
    
    static RandomAccessFile open(string filename, int openFlags, int openMode, int prot, int flags) {
        int fd = fcntl_open(cast(const char*)filename, openFlags, openMode);
        void *begin = MAP_FAILED;
        size_t length = 1<<31;

      attemptMmap:
        begin = mmap(null, length, prot, flags, fd, 0);
        if( begin == MAP_FAILED && length >= 0x200000 ) {
            length >>= 1;
            goto attemptMmap;
        }
        
        if( begin == MAP_FAILED ) throw new Exception(format("Failed to mmap '%s' from 0 to 0x%x", filename, length));
        void *end = begin + length;
        return new RandomAccessFile(fd, begin, end);
    }
    
    static RandomAccessFile open(string filename, bool writable) {
        // TODO: See if these flags are right
        return open(filename, writable?O_CREAT:0, octal!644, PROT_READ, MAP_SHARED);
    }
    
    void *at(long offset) {
        if( begin + offset > end ) {
            return null;
        } else {
            return begin + offset;
        }
    }
    
    byte[] get(long offset, size_t size) {
        byte[] result = new byte[size];
        byte *ptr = cast(byte *)at(offset);
        if( ptr == null ) {
            throw new Exception(format("Failed to turn offset 0x%x into a memory location; begin=0x%x, end=0x%x", offset, begin, end));
        }
        result[0..size] = (cast(byte *)at(offset))[0..size];
        return result;
    }
    
    void put(long offset, byte[] data) {
        
    }
}

class THHTFFile : RandomAccessFile {
    this(int fd, void *begin, void *end) {
        super(fd, begin, end);
    }
    /*
    static THHTFFile open( string filename, bool writeable ) {
    }
    
    Entry find( byte[] key ) {
    }
    */
}

void main() {
    Entry e = Entry( cast(byte[])"abc", cast(byte[])"def" );
    RandomAccessFile raf = RandomAccessFile.open("blah.dat", false);
    writeln("File size: ", raf.size);
    byte[] data = raf.get(raf.size-4, 4);
    writeln("Got some data! ", data);
}
