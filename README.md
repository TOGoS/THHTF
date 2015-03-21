# TOGoS's Homogenous Hash Table Format

Size of each entry and number of entries must be provided out of band, e.g. in the filename.

Therefore a standard filename format is needed.

Standard filename format: ```<whatever>.<key size>-<payload size>-<row size>[-<slop>].thht```

e.g. ```stored-blobs.20-0-1024.thht```

Primary use cases:

- Record a set of blobs by SHA-1: 20-0-1024.
- Record offsets/sizes of blobs in another file: 20-8-1024

Insertion is done by somehow hashing the key to an integer < $rowsize
and seeing if the value currently stored there has a key of all
zeroes, indicating 'nothing yet stored here'.  $rowsize will be added
to the index until a free space is found (expanding the file by a row
if necessary), at which point the key and value (concatenated
together) will be stored there.

Since the primary use case is using SHA-1 hashes as keys, the hash function
of these hashes may be trivial, such as using the upper several bits.

'Slop' refers to the number of spaces by which you can look forward in
the table for an entry if the first cell hit doesn't match.  By
default this is zero, so to add a new entry with the same hash, you'd
need to expand the file by another row.

## Key set files

  <whatever>.<key size>-0-<row size>[-<slop>].thht

Record a set of keys with no payload.  The payload size is zero and
the file consists entirely of keys (and zeroed out regions).

## Offset files

The standard format for storing variable sized blobs is to have a second file alongside the hash table.

  hashtable file = <whatever>.<key size>-8-<row size>[-<slop>].thht
  data file = <whatever>.dat

The data file may be completely unstructured, so long as blobs to be
addressed are formed from contiguous bytes.  The 8-byte payloads in
the hashtable file are treated as big-endian integers, where the top 4 bits
determine how the rest of the payload is interpreted:

    0000 = reserved
    0001 = the value 'true'
    0010 = the value 'false'
    0011 = reserved
    0100 = data is that at size16/offset44
    0101 = data is that at size16/offset44, deflated
    ...reserved...
    1000 0<size> = data is the lower <size> bytes of the payload

size16/offset44 means bits 0..43 give the offset and 44..59 the size
(both in bytes) of the blob within the file.  This allows storing up
to 16 TiB of data.

Reserved space may be used to indicate larger blobs at offsets
multiplied by some factor.
