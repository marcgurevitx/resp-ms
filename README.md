# Resp

Resp is a library for the [MiniScript](https://miniscript.org/) programming language that implements [RESP](https://github.com/redis/redis-specifications/blob/master/protocol/RESP3.md) serialization and deserialization.

The library can be used to exchange data with Redis or a Redis compatible database (if you find a way to connect to one from MiniScript), or alternatively it can be just used on its own for the serialization sake.

Your platform should have [RawData](https://miniscript.org/wiki/RawData) class compatible with the one in Mini Micro.


## Example

```c
import "resp"

x = {"foo": 42, "bar": [null, 4.3]}

r = resp.dump(x)
print r.utf8
// prints:
//  %2
//  +bar
//  *2
//  _
//  ,4.3
//  +foo
//  :42

x2 = resp.load(r)
print x2                // prints: {"bar": [null, 4.3], "foo": 42}
```

Another example: talking to a Keydb server using unix domain sockets (it uses a patched version of MiniScript).

```c
import "resp"

connection = uds.connect("/tmp/keydb.sock")

cmd = resp.command("SET k hello")

connection.send cmd

rep = connection.receive

print resp.load(rep)  // prints: OK

cmd = resp.command("GET k")

connection.send cmd

rep = connection.receive

print resp.load(rep).utf8  // prints: hello
```


## Install

You only need this file: `lib/resp.ms`.


## Overview

In very simple cases, the `load()` and `dump()` functions should suffice (see [High level API](#high-level-api)).

Since there is no one-to-one correspondence between MiniScript and RESP data types, the default conversion between them will lose info. There are three ways to overcome this:

* Use wrapper classes to manipulate RESP types directly (see [Wrappers](#wrappers)).
* Provide converter callbacks for the `load()` and `dump()` functions (see [Writing converter callbacks](#writing-converter-callbacks)).
* Define `._toRESPWrp()` for your classes (see [`_toRESPWrp()` callback](#_torespwrp-callback)).

Serialization and deserialization problems (like corrupted data, reference cycles etc) will result in `qa.abort()` beeing called (they crash). To avoid the crashes, pass `onError` callback to the `load()` / `dump()` (see [Writing `onError` callbacks](#writing-onerror-callbacks)).

If you're writing a stream-oriented code, there's a middle-level `Loader` class that is capable of consuming RESP from streams of `RawData` chunks (see [Loader](#loader)).

A low-level `RawDataCollection` class is a scary tree data type that is not meant to be used directly and is there to speed things up behind the scenes (at least I believe it should).

Finally, there is a couple of helper functions (see [Helpers](#helpers)):

* `str()` can replace the intrinsic `str` function and it calls `._str()` method of objects (good for debugging).
* `stringToRawData()` converts strings to `RawData` objects.
* `command()` produces Redis-compatible requests.


## High level API

![high level API](/data/hlapi.svg)


#### load()

`load(r, offset = 0, onError = null, wrptov = null) -> value`

Deserializes RESP into a MiniScript value. The `r` param can be a string, a RawData object or a list of RawData objects.

Deserialization conversions:

* Blob types (including streamed strings) become `RawData`.
* Null type becomes `null`.
* Simple string and simple error are converted to `string`.
* Numeric and boolean types are converted to `number`.
* Array and "push" types are converted to `list`.
* Map type is returned as `map`.
* "Set" type becomes a map of `{elem1: true, elem2: true, elem3: true, ...}`.
* Any attribute objects are dropped.

#### dump()

`dump(v, onError = null, vtowrp = null) -> RawData`

Serializes a MiniScript value into RESP. Returns a RawData object.

(There are more functions that do the same: `dumpToList()` returns a list of `RawData` objects that being put together make the same RESP, and `dumpToString()` returns a string.)

Serialization conversions:

* `null` is serialized as null type.
* Integer numbers are serialized as number type.
* Real numbers are serialized as double type.
* Strings without `<CR><LF>` are serialized as simple strings.
* Strings with `<CR><LF>` and `RawData` objects are serialized as blob strings.
* Lists become array type.
* Maps become map type.
* If a map has `_toRESPWrp()` method, it is called and the result is used to produce RESP (see [`_toRESPWrp()` callback](#_torespwrp-callback)).

Some values will not serialize: functions, unknown types (e.g handles) and maps with `__isa` (if they don't have `_toRESPWrp()`).


## Wrappers

![wrappers api](/data/wrapi.svg)

The high-level API doesn't preserve RESP types and attributes.

You can use wrapper classes (the descendants of `Wrp` class) to manipulate RESP types directly:

| RESP type | Wrapper class | General type category |
| --- | --- | --- |
| `$` blob string | `BlobStringWrp` | blob |
| `!` blob error | `BlobErrorWrp` | blob |
| `=` verbatim string | `VerbatimStringWrp` | blob |
| `+` simple string | `SimpleStringWrp` | line |
| `-` simple error | `SimpleErrorWrp` | line |
| `_` null | `NullWrp` | line |
| `:` number | `NumberWrp` | line (numeric) |
| `,` double | `DoubleWrp` | line (numeric) |
| `#` boolean | `BooleanWrp` | line (numeric) |
| `(` big number | `BigNumberWrp` | line (numeric) |
| `*` array | `ArrayWrp` | aggregate (list-like) |
| `~` set | `SetWrp` | aggregate (list-like) |
| `>` push | `PushWrp` | aggregate (list-like) |
| `%` map | `MapWrp` | aggregate (map-like) |
| `\|` attribute | `AttributeWrp` | aggregate (map-like) |

Additional wrappers to support streamed strings:

| RESP type | Wrapper class | General type category |
| --- | --- | --- |
| `$?` streamed string | `StreamedStringWrp` | aggregate (list-like) |
| `;` blob chunk | `BlobChunkWrp` | blob |

There are several ways to acquire a wrapper object in code:

* Use a class method `Wrp.fromRESP()` (instead of a `load()` function) to deserialize it from RESP.
* Use a class method `Wrp.fromValue()` to convert it from a MiniScript value using the default conversion rules.
* Construct a simple type using a `<class>.fromData()` factory.
* Construct an aggregate type using a `<class>.make()` factory and then add elements to it with its `push()` method.
* Use `loader.getWrp()`.

When you've acquired a warapper, you can:

* Use `toRESP()` / `toRESPList()` / `toRESPString()` methods to produce its RESP representation.
* Use `toValue()` to convert it to a MiniScript value using the default conversion rules.
* Extract the underlying data from simple types with their `toRawData()` / `toString()` / `toNumber()` methods.
* Access elements of an aggregate type through its `elements` property.

All wrappers can have an optional RESP "attribute" (an instance of `AttributeWrp` class). You can get/set it through `attribute` / `setAttribute()`.


#### Wrp.fromRESP()

`Wrp.fromRESP(r, offset = 0, onError = null) -> wrapper`

(*class method*) Deserializes RESP from a string, a RawData object or a list of RawData objects into a wrapper object.

#### \<wrapper>.toRESP()

`wrapper.toRESP() -> RawData`

Serializes a wrapper object into a RawData containing RESP.

(There are also `wrapper.toRESPList()` analogous to `dumpToList()` and `wrapper.toRESPString()` analogous to `dumpToString()`.)

#### Wrp.fromValue()

`Wrp.fromValue(v, onError = null, vtowrp = null) -> wrapper`

(*class method*) Creates a wrapper from a MiniScript value using the default conversion.

#### \<wrapper>.toValue()

`wrapper.toValue(wrptov = null) -> value`

Creates a MiniScript value from a wrapper using the default conversion.

#### \<blob or line class>.fromData()

`<blob or line class>.fromData(d) -> wrapper`

(*class method*) Create a wrapper with data `d` as its content.

```
import "resp"

w = resp.BigNumberWrp.fromData(42)
print w.toRESPString  // prints: (42<CR><LF>

w = resp.BlobErrorWrp.fromData("we're all doomed")
print w.toRESPString
// prints:
//  !16<CR><LF>
//  we're all doomed<CR><LF>
```

#### \<aggregate class>.make()

`<aggregate class>.make(isStreamed = false, hasHead = false, hasTail = false) -> wrapper`

(*class method*) Create an empty aggregate type wrapper.

This method of `StreamedStringWrp` class doesn't have `isStreamed` parameter: `StreamedStringWrp.make(hasHead = false, hasTail = false)`.

#### \<aggregate wrapper>.push()

`<aggregate wrapper>.push(x)`

Adds an element to an aggregate type wrapper.

List-like types (arrays, sets, pushes) expect the argument to be a wrapper object.

Map-like types (maps, atributes) expect the argument to be a list of two objects -- key and value: `[<wrapper>, <wrapper>]`.

Steramed strings will only accept `BlobChunkWrp` as an argument.

```c
import "resp"

w = resp.SetWrp.make
w.push resp.NumberWrp.fromData(100)
w.push resp.NumberWrp.fromData(200)
print w.toRESPString
// prints:
//  ~2<CR><LF>
//  :100<CR><LF>
//  :200<CR><LF>

w = resp.MapWrp.make
w.push [resp.SimpleStringWrp.fromData("foo"),
        resp.SimpleStringWrp.fromData("bar")]
print w.toRESPString
// prints:
//  %1<CR><LF>
//  +foo<CR><LF>
//  +bar<CR><LF>
```

#### \<blob or line wrapper>.toRawData()

`<blob or line wrapper>.toRawData -> RawData`

Extracts the content part of a blob or line type wrapper. Returns `RawData`.

#### \<line wrapper>.toString()

`<line wrapper>.toString -> string`

Extracts the content part of a line type wrapper and returns it as `string`.

#### \<numeric wrapper>.toNumber()

`<numeric wrapper>.toNumber -> number`

Extracts the content part of a numeric type wrapper and returns it as `number`.

#### \<aggregate wrapper>.elements

This property is a list of previously pushed elements.

#### \<wrapper>.attribute

This property is either `null` or an assigned `AttributeWrp` object.

#### \<wrapper>.setAttribute()

`<wrapper>.setAttribute(attribute)`

Assigns an attribute property to the wrapper.

```c
import "resp"

attr = resp.AttributeWrp.make
attr.push [resp.SimpleStringWrp.fromData("attr1"),
           resp.DoubleWrp.fromData("-1.23")]

w = resp.BooleanWrp.fromData(true)
w.setAttribute attr
print w.toRESPString
// prints:
//  |1<CR><LF>
//  +attr1<CR><LF>
//  ,-1.23<CR><LF>
//  #t<CR><LF>
```


## Writing `onError` callbacks

If a serialization or deserialization problem happens, `load()` and `dump()` functions will crash. To avoid uncaught errors, you can supply an `onError` callback.

`onError(errCode, arg1, arg2, offset) -> ...`

The `errCode` value denotes the problem (or event).

The meaning of `arg1` and `arg2` may differ for each `errCode`.

When deserializing, the `offset` is where in the subject the problem was encountered.

The return value of the callback becomes the return value of the caller.

| D/S | errCode | arg1 | arg2 | Meaning |
| --- | --- | --- | --- | --- |
| S | `"FROM_FUNC"` |  |  | Unable to serialize: the value is a function |
| S | `"FROM_CYCLES"` | value |  | Unable to serialize: the value has reference cycles |
| S | `"FROM_BAD_CALLBACK"` | result of `_toRESPWrp()` |  | Unable to serialize: `_toRESPWrp()` returned a value that is not a wrapper |
| S | `"FROM_ARB_INSTANCE"` | value |  | Unable to serialize: the value has `__isa` |
| S | `"FROM_ARB_TYPE"` | value |  | Unable to serialize: the value has unknown type |
| D | `"NOT_ENOUGH_DATA"` |  |  | (not an error) The input contains only a fragment of a RESP value |
| D | `"MORE_DATA"` |  |  | (not an error) The input has more bytes after the end of the RESP value |
| D | `"UNKNOWN_TYPE"` | type character | type character code | Unable to deserialize: value of unknown type |
| D | `"BAD_ELEM_TYPE"` | aggregate type character | element type character | Unable to deserialize: wrong type of an element in an aggregate |
| D | `"EMPTY_LENGTH"` |  |  | Unable to deserialize: Empty string instead of the value length |
| D | `"BAD_CHUNK"` | chunk length |  | Unable to deserialize: no `<CR><LF>` after a blob |
| D | `"STREAM_STARTED"` | aggregate |  | (not an error) A start marker for a steramed aggregate type is read |
| D | `"STREAM_ELEMENT"` | aggregate | element | (not an error) An element in the current steramed aggregate is read |
| D | `"STREAM_STOPPED"` | aggregate |  | (not an error) An end marker for the current steramed aggregate is read |

```c
import "resp"

onError = function(errCode, arg1, arg2, offset)
	print "problem = " + errCode
end function

v = resp.load("@foo", null, @onError)  // prints: problem = UNKNOWN_TYPE

r = resp.dump(@str, @onError)  // prints: problem = FROM_FUNC
```


## Writing converter callbacks

Functions `load()`, `dump()`, `Wrp.toValue()` and `Wrp.fromValue()` accept optional callback functions that can alter the types conversion process.

* `load()` and `Wrp.toValue()` accept a `wrptov()` callback.
* `dump()` and `Wrp.fromValue()` accept a `vtowrp()` callback.

(The actual function names are not important, but their signature and semantics differ.)

#### wrptov()  // wrapper-to-value

`wrptov(wrapper) -> value`

Converts a wrapper object into a MiniScript value.

If the callback returns `null`, the default type conversion takes place.

```c
import "resp"

wrptov = function(wrp)
	if wrp isa resp.NumericValueWrp then return "( " + wrp.toString + " )"
end function

v = resp.load("*2" + char(13) + char(10) +
              ":42" + char(13) + char(10) +
              "+foo" + char(13) + char(10), null, null, @wrptov)
print v  // prints: ["( 42 )", "foo"]
```

#### vtowrp()  // value-to-wrapper

`vtowrp(value) -> wrapper`

Converts a MiniScript value into a wrapper object.

If the callback returns `null`, the default type conversion takes place.

```c
import "resp"

vtowrp = function(v)
	if hasIndex(v, "foo") then return resp.SimpleStringWrp.fromData("( " + v.foo + " )")
end function

r = resp.dump([{"foo": 42}, {"bar": 43}], null, @vtowrp)
print r.utf8
// prints:
//  *2<CR><LF>
//  +( 42 )<CR><LF>
//  %1<CR><LF>
//  +bar<CR><LF>
//  :43<CR><LF>
```


## `_toRESPWrp()` callback

Arbitrary maps with `__isa` properties don't serialize to RESP. However, if such objects have `_toRESPWrp()` method, it is called and its result is used in conversion.

```c
import "resp"

A = {}
A._toRESPWrp = function
	return resp.SimpleStringWrp.fromData("( A )")
end function

r = resp.dump([new A, new A])
print r.utf8
// prints:
//  *2<CR><LF>
//  +( A )<CR><LF>
//  +( A )<CR><LF>
```


## Loader

![loader API](/data/ldapi.svg)

Loader is a class that consumes a stream of RawData objects and produces a stream of wrappers.

To create a loader use a `make()` factory.

Call `push()` and `getWrp()` to add RawData and read wrappers respectively.

#### Loader.make()

`Loader.make -> loader`

(*class method*)

#### \<loader>.push()

`<loader>.push(r)`

Adds a RawData chunk to the internal RawData collection.

#### \<loader>.getWrp()

`<loader>.getWrp(onError = null) -> wrapper`

Returns a wrapper object, or `null` if the internal RawData collection doesn't contain enough data for a whole value.

```c
import "resp"

l = resp.Loader.make

l.push "+foo"
l.push char(13) + char(10)
l.push "+bar" + char(13) + char(10) + "+baz"

print l.getWrp.toValue  // prints: foo
print l.getWrp.toValue  // prints: bar
print l.getWrp == null  // prints: 1
```


## Helpers

#### str()

`str(x, depth = null) -> string`

Replacement for built-in `str()` that calls `._str` if available.

#### stringToRawData()

`stringToRawData(s) -> RawData`

Returns a `RawData` object containing data from the string.

#### command()

`command(parts) -> RawData`

Encodes a message containing a Redis command.

```c
import "resp"

cmd = resp.command(["SET", "k", "foo"])
print cmd.utf8
// prints:
//  *3<CR><LF>
//  $3<CR><LF>
//  SET<CR><LF>
//  $1<CR><LF>
//  k<CR><LF>
//  $3<CR><LF>
//  foo<CR><LF>

cmd = resp.command("GET k")
print cmd.utf8
// prints:
//  *2<CR><LF>
//  $3<CR><LF>
//  GET<CR><LF>
//  $1<CR><LF>
//  k<CR><LF>
```
