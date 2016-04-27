<!-- -*- mode:gfm; word-wrap:nil -*- github-flavored markdown -->

# OpenX Erlang Thrift Implementation

`ox-thrift` is a reimplementation of the
[Apache Thrift](https://thrift.apache.org/) Erlang library with an
emphasis on speed of encoding and decoding.  In its current
incarnation, it uses the structure definitions produced by the Apache
Thrift code generator.  However it has the following differences from
the Apache Thrift Erlang library.

* It supports only framed transport.

* It gives up the ability to stream to or from the transport.
  Instead, the processor layer decodes the thrift message from a
  binary buffer and encodes to an iolist.  This simplifies the
  implementation and avoids a lot of record modifications that are
  inefficient in Erlang.

* The Thrift server uses the
  [ranch](https://github.com/ninenines/ranch) acceptor pool instead of
  rolling its own.

## Other Info

* Anthony pointed me to this talk on
  [The Fun Part of Writing a Thrift Codec](http://www.erlang-factory.com/static/upload/media/1442407543231431thefunpartofwritingathriftcodec.pdf),
  which describes one developer's work to speed up Thrift encoding and
  decoding.  Unfortunately, the code is not public. The author claims
  the following speedups:

  |Optimization   |Encoding|Decoding|
  |---------------|--------|--------|
  |Layer Squashing|8x      |2x      |
  |Generated Funs |16x     |16x     |

* Erlang documentation on
  [Constructing and Matching Binaries](http://erlang.org/doc/efficiency_guide/binaryhandling.html),
  which may be useful for optimization.