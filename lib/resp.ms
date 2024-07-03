import "importUtil"
ensureImport "qa"

version = "0.2.0"

sentinel = []
sentinel.push function ; end function

rn = char(13) + char(10)

errMsg = {}
errMsg.EMPTY_LENGTH = "empty length"
errMsg.UNKNOWN_TYPE = "unknown or unhandled type `{arg1}`, byte value = {arg2}"
errMsg.BAD_CHUNK = "no CRLF after a chunk of {arg1} bytes"
errMsg.BAD_ELEM_TYPE = "bad element type `{arg2}` within `{arg1}`-aggregate"
errMsg.MAX_DEPTH_EXCEEDED = "max depth exceeded"
errMsg.MAX_ELEMENTS_EXCEEDED = "max number of elements exceeded, got `{arg1}`"
errMsg.MAX_BLOB_LENGTH_EXCEEDED = "max length of a blob value exceeded, got `{arg1}`"
errMsg.MAX_LINE_LENGTH_EXCEEDED = "max length of a line value exceeded, got `{arg1}`"
errMsg.FROM_FUNC = "unable to make a wrapper for a funcRef"
errMsg.FROM_CYCLES = "cycles in data"
errMsg.FROM_BAD_CALLBACK = "expected _toRESPWrp to return a wrapper (resp.Wrp), got `{arg1}`"
errMsg.FROM_ARB_INSTANCE = "unable to make a wrapper for an arbitrary instance"
errMsg.FROM_ARB_TYPE = "unable to make a wrapper for this value: `{arg1}`"
_errMsg = errMsg




//
//   ------------------   U T I L S   ------------------
//


// from /sys/startup.ms
refIndexOf = function(l, item)
	i = 0; llen = l.len
	while i < llen
		if refEquals(l[i], @item) then return i
		i += 1
	end while
	return null
end function

// from /sys/lib/mapUtil.ms
mapGet = function(m, key, defaultValue = null)
	while m
		if m.hasIndex(@key) then return m[@key]
		if not m.hasIndex("__isa") then break
		m = m.__isa
	end while
	return @defaultValue
end function

// mapSetDefault: Returns  `m[key]`, sets `m[key]` to `defaultValue` if doesn't exist (like Python's dict.setDefault).
mapSetDefault = function(m, key, defaultValue)
	value = mapGet(m, @key, sentinel)
	if @value == sentinel then m[@key] = @defaultValue
	return m[@key]
end function

// str: Similar to vanilla `str`, but invokes a custom `._str` method if present.
str = function(x, depth = null, _nested = null)
	if depth == null or depth == 1/0 or depth < 0 then depth = 3
	if @x == null then
		if _nested then return "null" else return ""
	end if
	if @x isa string then
		if _nested then return intrinsics.str([x])[1:-1] else return x
	end if
	if @x isa list then
		if x.len == 0 then return "[]"
		if depth == 0 then return "[…(" + x.len + ")]"
		subs = []
		for elem in x
			subs.push str(@elem, depth - 1, true)
		end for
		return "[" + subs.join(", ") + "]"
	end if
	if @x isa map then
		if mapGet(x, "_str") then return x._str(depth)
		if x.hasIndex("_name") then return x._name
		if mapGet(x, "_name") then
			if mapGet(x, "_repr") then return x._name + "(" + x._repr(depth - 1) + ")"
			if mapGet(x, "_id") then return x._name + "(" + x._id + ")"
		end if
		if len(x) == 0 then return "{}"
		if depth == 0 then return "{…(" + x.len + ")}"
		subs = []
		for kv in x
			subs.push str(@kv.key, depth - 1, true) + ": " + str(@kv.value, depth - 1, true)
		end for
		return "{" + subs.join(", ") + "}"
	end if
	return intrinsics.str(@x)
end function

// rawDataCmp: Compares two RawData objects, returns `-1` if `r1<r2`, `0` if `r1==r2` and `-1` if `r1>r2`.
rawDataCmp = function(r1, r2)
	i = 0
	while true
		if i == r1.len and i == r2.len then return 0
		if i == r1.len then return -1
		if i == r2.len then return 1
		byte1 = r1.byte(i)
		byte2 = r2.byte(i)
		if byte1 < byte2 then return -1
		if byte1 > byte2 then return 1
		i += 1
	end while
end function

// stringToRawData: Returns a new RawData object containing `s`.
stringToRawData = function(s)
	r = new RawData
	r.resize s.len * 4
	r.resize r.setUtf8(0, s)
	return r
end function

// rawDataToString: Returns a string containing RawData's content.
rawDataToString = function(r)
	if r.len == 0 then return ""
	return r.utf8
end function



//
//   ------------------   RawData  C O L L E C T I O N   ------------------
//


// ???
RawDataCollection = {}
RawDataCollection._name = "resp:RawDataCollection"
RawDataCollection.init = function(rr = null)
	if rr == null then rr = []
	if not rr isa list then rr = [rr]
	self.list = []
	self.offset = 0
	self.len = 0
	for r in rr
		self.push r
	end for
	return self
end function

RawDataCollection.make = function(rr = null)
	return (new self).init(@rr)
end function

// ???
RawDataCollection.totalBytes = function
	t = 0
	for r in self.list
		t += r.len
	end for
	return t
end function

// ???
RawDataCollection.push = function(r, keepLengthP = false)
	if @r isa string then r = stringToRawData(r)
	if not (@r isa RawData or @r isa RawDataCollection) then qa.abort "expected RawData or RawDataCollection, got `" + str(@r) + "`"
	self.list.push r
	if not keepLengthP then self.len += r.len
end function

// ???
RawDataCollection.tailBytes = function
	return self.totalBytes - self.offset - self.len
end function

// ???
RawDataCollection.advance = function(nBytes)
	if self.offset + nBytes < 0 then nBytes = -self.offset
	self.offset += nBytes
	self.len -= nBytes
	if self.len < 0 then self.len = 0
	l = []
	for r in self.list
		if self.offset >= r.len then
			self.offset -= r.len
			continue
		end if
		l.push r
	end for
	self.list = l
end function

// ???
RawDataCollection.grow = function(nBytes)
	self.len += nBytes
	if self.len < 0 then self.len = 0
	maxLen = self.totalBytes - self.offset
	if self.len > maxLen then self.len = maxLen
end function

// ???
RawDataCollection.toRawData = function(offset = 0, nBytes = null, _acc = null, _accIndex = null)
	if offset == null or offset < 0 then offset = 0
	if nBytes == null or offset + nBytes > self.len then nBytes = self.len - offset
	nBytes = floor(nBytes)
	if nBytes <= 0 then return new RawData
	offset += self.offset
	if _acc == null then
		_acc = new RawData
		_acc.resize nBytes
		_accIndex = 0
	end if
	for r in self.list
		if offset >= r.len then
			offset -= r.len
			continue
		end if
		if offset + nBytes <= r.len then
			self._slurpRawData r, offset, nBytes, _acc, _accIndex
			break
		else
			nToSlurp = r.len - offset
			self._slurpRawData r, offset, nToSlurp, _acc, _accIndex
			offset = 0
			nBytes -= nToSlurp
			_accIndex += nToSlurp
		end if
	end for
	return _acc
end function

// ???
RawDataCollection._slurpRawData = function(r, offset, nBytes, _acc, _accIndex)
	if r isa RawDataCollection then r.toRawData offset, nBytes, _acc, _accIndex
	if r isa RawData then
		for i in range(0, nBytes - 1, 1)
			_acc.setByte _accIndex + i, r.byte(offset + i)
		end for
	end if
end function

// ???
RawDataCollection.toRawDataList = function(offset = 0, nBytes = null, _rdl = null)
	if offset == null or offset < 0 then offset = 0
	if nBytes == null or offset + nBytes > self.len then nBytes = self.len - offset
	nBytes = floor(nBytes)
	if nBytes <= 0 then return new RawData
	offset += self.offset
	if _rdl == null then _rdl = []
	for r in self.list
		if offset >= r.len then
			offset -= r.len
			continue
		end if
		if offset + nBytes <= r.len then
			self._slurpRawDataList r, offset, nBytes, _rdl
			break
		else
			nToSlurp = r.len - offset
			self._slurpRawDataList r, offset, nToSlurp, _rdl
			offset = 0
			nBytes -= nToSlurp
		end if
	end for
	return _rdl
end function

// ???
RawDataCollection._slurpRawDataList = function(r, offset, nBytes, _rdl)
	if r isa RawDataCollection then r.toRawDataList offset, nBytes, _rdl
	if r isa RawData then
		if offset == 0 and nBytes == r.len then
			_rdl.push r
			return
		end if
		acc = new RawData
		acc.resize nBytes
		accIndex = 0
		for i in range(0, nBytes - 1, 1)
			acc.setByte accIndex + i, r.byte(offset + i)
		end for
		_rdl.push acc
	end if
end function

// ???
RawDataCollection.copy = function
	r = self + {}
	r.list = r.list[:]
	return r
end function

// ???
RawDataCollection.indexOf = function(x, after = 0)
	if x isa string then x = stringToRawData(x)
	if after == null then after = 0
	if after + x.len > self.len then return null
	for i in range(after, self.len - x.len, 1)
		r = self.toRawData(i, x.len)
		if rawDataCmp(x, r) == 0 then return i
	end for
	return null
end function




//
//   ------------------   W R A P P E R S   ------------------
//


//   ---------
//  |   Wrp   |
//   ---------
//      .typeCharacter
//      .setAttribute
//      .attribute
//      .fromValue
//      .toValue
//      .fromRESP
//      .toRESP
//      .toRESPList
//      .toRESPString
//      .toRESPCollection
//
//      |          ----------------
//      +-------> | SimpleValueWrp |
//      |          ----------------
//      |                 .fromData(d)
//      |                 .rdcol  // RawDataCollection
//      |                 .toRawData
//      |
//      |                 |             --------------
//      |                 +----------> | BlobValueWrp |
//      |                 |             --------------
//      |                 |                   |           +---------------+
//      |                 |                   +---------> | BlobStringWrp |      // $<N>...
//      |                 |                   |           +---------------+
//      |                 |                   |           +--------------+
//      |                 |                   +---------> | BlobErrorWrp |       // !<N>...
//      |                 |                   |           +--------------+
//      |                 |                   |           +-------------------+
//      |                 |                   +---------> | VerbatimStringWrp |  // =<N>...
//      |                 |                   |           +-------------------+
//      |                 |                   |                    .fromFormatAndData(fmt, d)
//      |                 |                   |
//      |                 |                   |           +--------------+
//      |                 |                   +---------> | BlobChunkWrp |       // ;<N>...
//      |                 |                               +--------------+
//      |                 |             --------------
//      |                 +----------> | LineValueWrp |
//      |                               --------------
//      |                                     .toString
//      |
//      |                                     |           +-----------------+
//      |                                     +---------> | SimpleStringWrp |    // +...
//      |                                     |           +-----------------+
//      |                                     |           +----------------+
//      |                                     +---------> | SimpleErrorWrp |     // -...
//      |                                     |           +----------------+
//      |                                     |           +---------+
//      |                                     +---------> | NullWrp |            // _..., $-1, *-1
//      |                                     |           +---------+
//      |                                     |                .make(typeCharacter = "_")
//      |                                     |
//      |                                     |            -----------------
//      |                                     +---------> | NumericValueWrp |
//      |                                                  -----------------
//      |                                                          .toNumber
//      |
//      |                                                          |           +-----------+
//      |                                                          +---------> | NumberWrp |     // :...
//      |                                                          |           +-----------+
//      |                                                          |           +-----------+
//      |                                                          +---------> | DoubleWrp |     // ,...
//      |                                                          |           +-----------+
//      |                                                          |           +------------+
//      |                                                          +---------> | BooleanWrp |    // #...
//      |                                                          |           +------------+
//      |                                                          |           +--------------+
//      |                                                          +---------> | BigNumberWrp |  // (...
//      |                                                                      +--------------+
//      |          -------------------
//      +-------> | AggregateValueWrp |
//                 -------------------
//                          .make(isStreamed, hasHead, hasTail)
//                          .push(elem)
//                          .elements  // [...]
//
//                          |              ------------------
//                          +-----------> | ListLikeValueWrp |
//                          |              ------------------
//                          |                      |             +----------+
//                          |                      +-----------> | ArrayWrp |           // *<N>..., *?...
//                          |                      |             +----------+
//                          |                      |             +--------+
//                          |                      +-----------> | SetWrp |             // ~<N>..., ~?...
//                          |                      |             +--------+
//                          |                      |             +---------+
//                          |                      +-----------> | PushWrp |            // ><N>..., >?...
//                          |                      |             +---------+
//                          |                      |             +-------------------+
//                          |                      +-----------> | StreamedStringWrp |  // $?...
//                          |                                    +-------------------+
//                          |                                              .make(hasHead, hasTail)
//                          |                                              .toRawData
//                          |
//                          |              -----------------
//                          +-----------> | MapLikeValueWrp |
//                                         -----------------
//                                                 |             +--------+
//                                                 +-----------> | MapWrp |             // %<N>..., %?...
//                                                 |             +--------+
//                                                 |             +--------------+
//                                                 +-----------> | AttributeWrp |       // |<N>..., |?...
//                                                               +--------------+



// ???
Wrp = {}
Wrp._name = "resp:Wrp"
Wrp.attribute = null

Wrp.setAttribute = function(attribute)
	if not attribute isa AttributeWrp then qa.abort "expected an attribute (resp.AttributeWrp), got `" + str(attribute) + "`"
	self.attribute = attribute
end function

Wrp.fromValue = function(v, onError = null, vtowrp = null, _seen = null)
	if _seen == null then
		_seen = []
		_errMsg = @outer._errMsg
		
		_err = function(errCode, arg1 = null)
			if @onError != null then return onError(errCode, @arg1)
			msg = _errMsg[errCode]
			msg = msg.replace("{arg1}", str(@arg1))
			qa.abort msg
		end function
		
	else
		
		_err = function(errCode, arg1 = null)
			return [errCode, arg1]
		end function
		
	end if
	if @vtowrp != null then
		wrp = vtowrp(@v)
		if wrp != null then return wrp
	end if
	if @v isa funcRef then return _err("FROM_FUNC")
	if v == null then return NullWrp.make
	if v isa number then
		if v == 1/0 then return DoubleWrp.fromData("inf")
		if v == -1/0 then return DoubleWrp.fromData("-inf")
		if v != v then return DoubleWrp.fromData("nan")
		if v == sign(v) * floor(abs(v)) then return NumberWrp.fromData(v)
		return DoubleWrp.fromData(v)
	end if
	if v isa string then
		if v.indexOf(rn) == null and v.indexOf(char(0)) == null then return SimpleStringWrp.fromData(v)
		return BlobStringWrp.fromData(v)
	end if
	if v isa list then
		if refIndexOf(_seen, v) != null then return _err("FROM_CYCLES", v)
		_seen.push v
		w = ArrayWrp.make
		for elem in v
			elemWrp = Wrp.fromValue(elem, @onError, @vtowrp, _seen)
			if elemWrp isa list then return _err(elemWrp[0], elemWrp[1])
			w.pushValue elemWrp
		end for
		return w
	end if
	if v isa map then
		if refIndexOf(_seen, v) != null then return _err("FROM_CYCLES", v)
		_seen.push v
		if v isa RawData then return BlobStringWrp.fromData(v)
		if mapGet(v, "_toRESPWrp") then
			w = v._toRESPWrp
			if not w isa Wrp then return _err("FROM_BAD_CALLBACK", w)
			return w
		end if
		if v.hasIndex("__isa") then return _err("FROM_ARB_INSTANCE", v)
		w = MapWrp.make
		for kv in v
			kWrp = Wrp.fromValue(@kv.key, @onError, @vtowrp, _seen)
			if kWrp isa list then return _err(kWrp[0], kWrp[1])
			vWrp = Wrp.fromValue(@kv.value, @onError, @vtowrp, _seen)
			if vWrp isa list then return _err(vWrp[0], vWrp[1])
			w.pushKeyValue kWrp,  // in Cincinnati
			               vWrp
		end for
		return w
	end if
	return _err("FROM_ARB_TYPE", v)
end function

Wrp.toValue = function(wrptov = null)
	if @wrptov != null then
		v = wrptov(self)
		if @v == sentinel then return null
		if @v != null then return @v
	end if
	return self._convert(@wrptov)
end function

Wrp.fromRESP = function(r, onError = null)
	if not r isa list then r = [r]
	errRet = null
	sentinel = @outer.sentinel
	
	_err = function(errCode, arg1, arg2, offset)
		if @onError != null then outer.errRet = onError(errCode, arg1, arg2, offset)
		return sentinel
	end function
	
	l = Loader.make
	for x in r
		ret = l.pushData(x, @_err)
		if ret == sentinel then return errRet
	end for
	return l.getWrp
end function

Wrp.manyFromRESP = function(r, onError = null)
	if not r isa list then r = [r]
	errRet = null
	sentinel = @outer.sentinel
	
	_err = function(errCode, arg1, arg2, offset)
		if @onError != null then outer.errRet = onError(errCode, arg1, arg2, offset)
		return sentinel
	end function
	
	l = Loader.make
	for x in r
		ret = l.pushData(x, @_err)
		if ret == sentinel then return errRet
	end for
	return l.getAllWrps
end function

Wrp._startRESP = function(rdcol)
	r = RawDataCollection.make
	if self.attribute then r.push self.attribute.toRESPCollection
	return r
end function

Wrp.toRESPCollection = function ; qa.abort "implement me" ; end function

Wrp.toRESP = function
	return self.toRESPCollection.toRawData
end function

Wrp.toRESPList = function
	return self.toRESPCollection.toRawDataList
end function

Wrp.toRESPString = function
	return self.toRESPCollection.toRawData.utf8
end function



// ???
SimpleValueWrp = new Wrp
SimpleValueWrp._name = "resp:SimpleValueWrp"

SimpleValueWrp.fromData = function(d)
	x = new self
	x.rdcol = RawDataCollection.make
	x.rdcol.push d
	return x
end function

SimpleValueWrp.toRawData = function
	return self.rdcol.toRawData
end function



// ???
BlobValueWrp = new SimpleValueWrp
BlobValueWrp._name = "resp:BlobValueWrp"

BlobValueWrp.toRESPCollection = function
	r = self._startRESP
	r.push self.typeCharacter + self.rdcol.len + rn
	r.push self.rdcol.toRawData
	r.push rn
	return r
end function

BlobValueWrp._convert = function(wrptov)
	return self.toRawData
end function



// ???
BlobStringWrp = new BlobValueWrp
BlobStringWrp._name = "resp:BlobStringWrp"
BlobStringWrp.typeCharacter = "$"



// ???
BlobErrorWrp = new BlobValueWrp
BlobErrorWrp._name = "resp:BlobErrorWrp"
BlobErrorWrp.typeCharacter = "!"



// ???
VerbatimStringWrp = new BlobValueWrp
VerbatimStringWrp._name = "resp:VerbatimStringWrp"
VerbatimStringWrp.typeCharacter = "="

VerbatimStringWrp.fromFormatAndData = function(format, d)
	x = new self
	x.rdcol = RawDataCollection.make
	x.rdcol.push format + ":"
	x.rdcol.push d
	x.format = format
	return x
end function



// ???
BlobChunkWrp = new BlobValueWrp
BlobChunkWrp._name = "resp:BlobChunkWrp"
BlobChunkWrp.typeCharacter = ";"



// ???
LineValueWrp = new SimpleValueWrp
LineValueWrp._name = "resp:LineValueWrp"

LineValueWrp.fromData = function(d, nullOnCrLf = false)
	if d == null then return NullWrp.make
	if d isa string then
		s = d
	else if d isa RawData then
		if d.len == 0 then s = "" else s = d.utf8
	else if d isa RawDataCollection then
		r = d.toRawData
		if r.len == 0 then s = "" else s = r.utf8
	else
		d = str(d)
		s = d
	end if
	crLfIndex = s.indexOf(rn)
	if crLfIndex != null then
		if nullOnCrLf then return null
		d = s[:crLfIndex]
	end if
	x = super.fromData(d)
	return x
end function

LineValueWrp.toString = function
	r = self.toRawData
	if r.len == 0 then return ""
	return r.utf8
end function

LineValueWrp.toRESPCollection = function
	r = self._startRESP
	r.push self.typeCharacter
	r.push self.rdcol.toRawData
	r.push rn
	return r
end function

LineValueWrp._convert = function(wrptov)
	return self.toString
end function



// ???
SimpleStringWrp = new LineValueWrp
SimpleStringWrp._name = "resp:SimpleStringWrp"
SimpleStringWrp.typeCharacter = "+"



// ???
SimpleErrorWrp = new LineValueWrp
SimpleErrorWrp._name = "resp:SimpleErrorWrp"
SimpleErrorWrp.typeCharacter = "-"



// ???
NullWrp = new LineValueWrp
NullWrp._name = "resp:NullWrp"

NullWrp.make = function(typeCharacter = "_")
	if typeCharacter == null then typeCharacter = "_"
	x = self.fromData("")
	x.typeCharacter = typeCharacter
	return x
end function

NullWrp.toRESPCollection = function
	if self.typeCharacter == "_" then
		s = "_" + rn
	else if self.typeCharacter == "$" then
		s = "$-1" + rn
	else if self.typeCharacter == "*" then
		s = "*-1" + rn
	end if
	r = self._startRESP
	r.push s
	return r
end function

NullWrp._convert = function(wrptov)
	return null
end function



// ???
NumericValueWrp = new LineValueWrp
NumericValueWrp._name = "resp:NumericValueWrp"

NumericValueWrp.toNumber = function
	return self.toString.val
end function

NumericValueWrp._convert = function(wrptov)
	return self.toNumber
end function



// ???
NumberWrp = new NumericValueWrp
NumberWrp._name = "resp:NumberWrp"
NumberWrp.typeCharacter = ":"

NumberWrp.fromData = function(d, nullOnCrLf = false)
	if d == 1/0 or d == -1/0 or d != d then qa.abort "cannot convert `" + str(d) + "` to a RESP number"
	if d isa string then
		n = d.val
	else if d isa RawData then
		if d.len == 0 then n = 0 else n = d.utf8.val
	else if d isa RawDataCollection then
		r = d.toRawData
		if r.len == 0 then n = 0 else n = r.utf8.val
	else
		n = d
	end if
	n = sign(n) * floor(abs(n))
	return super.fromData(str(n), nullOnCrLf)
end function



// ???
DoubleWrp = new NumericValueWrp
DoubleWrp._name = "resp:DoubleWrp"
DoubleWrp.typeCharacter = ","

DoubleWrp.toNumber = function
	s = self.toString
	if s == "inf" then return 1/0
	if s == "-inf" then return -1/0
	if s == "nan" then return 0/0
	return super.toNumber
end function



// ???
BooleanWrp = new NumericValueWrp
BooleanWrp._name = "resp:BooleanWrp"
BooleanWrp.typeCharacter = "#"

BooleanWrp.fromData = function(d, nullOnCrLf = false)
	if not d isa string and not d isa RawData and not d isa RawDataCollection then
		if d then d = "t" else d = "f"
	end if
	return super.fromData(d, nullOnCrLf)
end function

BooleanWrp.toNumber = function
	s = self.toString
	if s == "t" then return true
	if s == "f" then return false
	return super.toNumber
end function



// ???
BigNumberWrp = new NumericValueWrp
BigNumberWrp._name = "resp:BigNumberWrp"
BigNumberWrp.typeCharacter = "("



// ???
AggregateValueWrp = new Wrp
AggregateValueWrp._name = "resp:AggregateValueWrp"

AggregateValueWrp.make = function(isStreamed = false, hasHead = false, hasTail = false)
	x = new self
	x.elements = []
	x.isStreamed = isStreamed
	x.hasHead = hasHead
	x.hasTail = hasTail
	return x
end function

AggregateValueWrp.assertElement = function(elem)
	if elem isa AttributeWrp then qa.abort "attribute type cannot be an element in an aggregate"
	if not elem isa Wrp then qa.abort "expected a RESP wrapper (resp.Wrp), got `" + str(elem) + "`"
end function



// ???
ListLikeValueWrp = new AggregateValueWrp
ListLikeValueWrp._name = "resp:ListLikeValueWrp"

ListLikeValueWrp.toRESPCollection = function(tailLine = ".")
	if tailLine == null then tailLine = "."
	r = self._startRESP
	if not self.isStreamed then
		r.push self.typeCharacter + self.elements.len + rn
	else if self.hasHead then
		r.push self.typeCharacter + "?" + rn
	end if
	for v in self.elements
		r.push v.toRESPCollection
	end for
	if self.isStreamed and self.hasTail then r.push tailLine + rn
	return r
end function

ListLikeValueWrp.pushValue = function(v)
	self.assertElement v
	self.elements.push v
end function

ListLikeValueWrp._convert = function(wrptov)
	l = []
	for elem in self.elements
		l.push elem.toValue(@wrptov)
	end for
	return l
end function



// ???
ArrayWrp = new ListLikeValueWrp
ArrayWrp._name = "resp:ArrayWrp"
ArrayWrp.typeCharacter = "*"



// ???
SetWrp = new ListLikeValueWrp
SetWrp._name = "resp:SetWrp"
SetWrp.typeCharacter = "~"

SetWrp._convert = function(wrptov)
	m = {}
	for elem in self.elements
		m.push elem.toValue(@wrptov)
	end for
	return m
end function



// ???
PushWrp = new ListLikeValueWrp
PushWrp._name = "resp:PushWrp"
PushWrp.typeCharacter = ">"



// ???
StreamedStringWrp = new ListLikeValueWrp
StreamedStringWrp._name = "resp:StreamedStringWrp"
StreamedStringWrp.typeCharacter = "$"

StreamedStringWrp.make = function(hasHead = false, hasTail = false)
	return super.make(true, hasHead, hasTail)
end function

StreamedStringWrp.toRESPCollection = function
	return super.toRESPCollection(";0")
end function

StreamedStringWrp.pushValue = function(v)
	if v isa string then v = BlobChunkWrp.fromData(v)
	if not v isa BlobChunkWrp then qa.abort "expected a streamed string element (resp.BlobChunkWrp), got `" + str(v) + "`"
	super.pushValue v
end function

StreamedStringWrp.toRawData = function(offset = null, nBytes = null)
	r = RawDataCollection.make
	for elem in self.elements
		r.push elem.rdcol
	end for
	return r.toRawData(offset, nBytes)
end function

StreamedStringWrp._convert = function(wrptov)
	r = RawDataCollection.make
	for elem in self.elements
		r.push elem.rdcol
	end for
	return r.toRawData
end function



// ???
MapLikeValueWrp = new AggregateValueWrp
MapLikeValueWrp._name = "resp:MapLikeValueWrp"

MapLikeValueWrp.toRESPCollection = function
	r = self._startRESP
	if not self.isStreamed then
		r.push self.typeCharacter + self.elements.len + rn
	else if self.hasHead then
		r.push self.typeCharacter + "?" + rn
	end if
	for p in self.elements
		r.push p[0].toRESPCollection
		r.push p[1].toRESPCollection
	end for
	if self.isStreamed and self.hasTail then r.push "." + rn
	return r
end function

MapLikeValueWrp.pushKeyValue = function(k, v)
	self.assertElement k
	self.assertElement v
	self.elements.push [k, v]
end function

MapLikeValueWrp._convert = function(wrptov)
	m = {}
	for p in self.elements
		k = p[0].toValue(@wrptov)
		v = p[1].toValue(@wrptov)
		m[@k] = @v
	end for
	return m
end function



// ???
MapWrp = new MapLikeValueWrp
MapWrp._name = "resp:MapWrp"
MapWrp.typeCharacter = "%"



// ???
AttributeWrp = new MapLikeValueWrp
AttributeWrp._name = "resp:AttributeWrp"
AttributeWrp.typeCharacter = "|"




//
//   ------------------   L O A D E R   ------------------
//


// ???
Loader = {}
Loader._name = "resp:Loader"
Loader.maxDepth = 1/0
Loader.maxElements = 1/0
Loader.maxBlobLength = 1/0
Loader.maxLineLength = 1/0

Loader.make = function
	x = new self
	x.rdcol = RawDataCollection.make
	x.wrps = []
	x.state = "BEGIN"
	x.stack = []
	x.attribute = null
	x.offset = 0
	x.typeCharacter = null
	return x
end function

// ???
Loader.pushData = function(r, onError = null)
	self.rdcol.push r
	loader = self
	if @onError != null then
		
		_err = function(errCode, arg1 = null, arg2 = null)
			return onError(errCode, arg1, arg2, loader.offset)
		end function
		
	else
		_errMsg = @outer._errMsg
		
		_err = function(errCode, arg1 = null, arg2 = null)
			if errCode[:7] == "STREAM_" then return arg1
			msg = _errMsg[errCode]
			msg = msg.replace("{arg1}", str(@arg1))
			msg = msg.replace("{arg2}", str(@arg2))
			qa.abort msg + " (offset = " + str(loader.offset) + ")"
		end function
		
	end if
	while true
		if self.state == "BEGIN" then
			typeCharacter = self._eatCharacter
			if typeCharacter == null then return null
			if self.stack.len > 0 then
				a = self.stack[-1]
				if a.wrp isa StreamedStringWrp then
					if typeCharacter != ";" then
						self.offset -= 1
						return _err("BAD_ELEM_TYPE", "$", typeCharacter)
					end if
				else
					if typeCharacter == ";" then
						self.offset -= 1
						return _err("BAD_ELEM_TYPE", a.wrp.typeCharacter, ";")
					end if
				end if
			end if
			if "+-:_,#($!=;*%~>|.".indexOf(typeCharacter) == null then
				self.offset -= 1
				return _err("UNKNOWN_TYPE", typeCharacter, typeCharacter.code)
			end if
			self.typeCharacter = typeCharacter
			self.state = "LINE"
			continue
		else if self.state == "LINE" then
			typeCharacter = self.typeCharacter
			tail = self._eatLine(@_err)
			if tail == null then return null
			if self.stack.len > 0 then
				a = self.stack[-1]
				if typeCharacter == "." or (typeCharacter == ";" and tail.toRawData.utf8 == "0") then
					a.length = 0
					if a.wrp.isStreamed then _err("STREAM_STOPPED", a.wrp)
					self.state = "ELEMENTS"
					continue
				end if
			end if
			value = null
			if typeCharacter == "+" then
				value = SimpleStringWrp.fromData(tail)
			else if typeCharacter == "-" then
				value = SimpleErrorWrp.fromData(tail)
			else if typeCharacter == ":" then
				value = NumberWrp.fromData(tail)
			else if typeCharacter == "_" then
				value = NullWrp.make(typeCharacter)
			else if typeCharacter == "," then
				value = DoubleWrp.fromData(tail)
			else if typeCharacter == "#" then
				value = BooleanWrp.fromData(tail)
			else if typeCharacter == "(" then
				value = BigNumberWrp.fromData(tail)
			end if
			if value != null then
				self.state = "READY"
				continue
			end if
			s = tail.toRawData.utf8
			if not s then
				self.offset -= 2
				return _err("EMPTY_LENGTH")
			end if
			if s == "-1" then
				value = NullWrp.make(typeCharacter)
				self.state = "READY"
				continue
			end if
			if s == "?" then length = null else length = s.val
			if length != null then
				blobWrp = null
				if typeCharacter == "$" then
					blobWrp = BlobStringWrp
				else if typeCharacter == "!" then
					blobWrp = BlobErrorWrp
				else if typeCharacter == "=" then
					blobWrp = VerbatimStringWrp
				else if typeCharacter == ";" then
					blobWrp = BlobChunkWrp
				end if
				if blobWrp != null then
					if length > self.maxBlobLength then return _err("MAX_BLOB_LENGTH_EXCEEDED", length)
					self.stack.push {"class": blobWrp, "length": length}
					self.state = "BLOB"
					continue
				end if
				if length > self.maxElements then return _err("MAX_ELEMENTS_EXCEEDED", length)
			end if
			wrp = null
			ending = "."
			if typeCharacter == "$" then
				wrp = StreamedStringWrp.make(true, true)
				ending = ";0"
			else if typeCharacter == "*" then
				wrp = ArrayWrp.make(length == null, true, true)
			else if typeCharacter == "%" then
				wrp = MapWrp.make(length == null, true, true)
				if length != null then length *= 2
			else if typeCharacter == "~" then
				wrp = SetWrp.make(length == null, true, true)
			else if typeCharacter == ">" then
				wrp = PushWrp.make(length == null, true, true)
			else if typeCharacter == "|" then
				wrp = AttributeWrp.make(length == null, true, true)
				if length != null then length *= 2
			end if
			if wrp != null then
				if wrp.isStreamed then _err("STREAM_STARTED", wrp)
				self.stack.push {"wrp": wrp, "length": length, "ending": ending, "acc": [], "attribute": self.attribute}
				if self.stack.len > self.maxDepth then return _err("MAX_DEPTH_EXCEEDED")
				self.attribute = null
				self.state = "ELEMENTS"
				continue
			end if
			self.offset -= 4
			return _err("UNKNOWN_TYPE", typeCharacter, typeCharacter.code)
		else if self.state == "BLOB" then
			b = self.stack[-1]
			chunk = self._eatChunk(b.length)
			if chunk == null then return null
			if chunk == false then
				return _err("BAD_CHUNK", b.length)
			end if
			self.stack.pop  // blob info
			value = b.class.fromData(chunk)
			self.state = "READY"
			continue
		else if self.state == "ELEMENTS" then
			a = self.stack[-1]
			if a.length == null or a.length > 0 then
				self.state = "BEGIN"
				continue
			end if
			self.stack.pop  // aggregate info
			v = a.wrp
			pair = []
			for elem in a.acc
				if v isa MapLikeValueWrp then
					pair.push elem
					if pair.len == 2 then
						v.pushKeyValue pair[0], pair[1]
						pair = []
					end if
				else
					v.pushValue elem
				end if
			end for
			if a.attribute != null then v.setAttribute a.attribute
			if v isa AttributeWrp then
				self.attribute = v
				self.state = "BEGIN"
				continue
			end if
			value = v
			self.state = "READY"
			continue
		else if self.state == "READY" then
			if self.attribute != null then
				value.setAttribute self.attribute
				self.attribute = null
			end if
			if self.stack.len == 0 then
				self.state = "BEGIN"
				self.wrps.push value
				continue
			end if
			a = self.stack[-1]
			a.acc.push value
			if a.length != null then a.length -= 1
			if a.wrp.isStreamed then _err("STREAM_ELEMENT", a.wrp, value)
			self.state = "ELEMENTS"
			continue
		else
			qa.abort "unknown state: `" + str(self.state) + "`"
		end if
	end while
end function

// ???
Loader.getWrp = function
	return self.wrps.pull
end function

// ???
Loader.getAllWrps = function
	ret = self.wrps[:]
	self.wrps = []
	return ret
end function

Loader._eatCharacter = function
	c = self.rdcol.toRawData(0, 1).utf8
	if not c then return null
	self.rdcol.advance 1
	self.offset += 1
	return c
end function

Loader._eatLine = function(_err)
	rnIndex = self.rdcol.indexOf(rn)
	if rnIndex == null then return null
	if rnIndex > self.maxLineLength then return _err("MAX_LINE_LENGTH_EXCEEDED", rnIndex)
	line = self.rdcol.copy
	line.len = rnIndex
	self.rdcol.advance rnIndex + 2
	self.offset += rnIndex + 2
	return line
end function

Loader._eatChunk = function(nBytes)
	if nBytes + 2 > self.rdcol.len then return null
	if self.rdcol.toRawData(nBytes, 2).utf8 != rn then return false
	chunk = self.rdcol.copy
	chunk.len = nBytes
	self.rdcol.advance nBytes + 2
	self.offset += nBytes + 2
	return chunk
end function




//
//   ------------------   H I G H  L E V E L  A P I   ------------------
//


// ???
load = function(r, onError = null, wrptov = null)
	wrp = Wrp.fromRESP(r, @onError)
	if not wrp isa Wrp then return wrp
	return wrp.toValue(@wrptov)
end function

// ???
loadMany = function(r, onError = null, wrptov = null)
	wrps = Wrp.manyFromRESP(r, @onError)
	vv = []
	for wrp in wrps
		vv.push wrp.toValue(@wrptov)
	end for
	return vv
end function

// ???
dump = function(v, onError = null, vtowrp = null)
	wrp = Wrp.fromValue(@v, @onError, @vtowrp)
	if wrp == null then return null
	return wrp.toRESP
end function

// ???
dumpToList = function(v, onError = null, vtowrp = null)
	wrp = Wrp.fromValue(@v, @onError, @vtowrp)
	if wrp == null then return null
	return wrp.toRESPList
end function

// ???
dumpToString = function(v, onError = null, vtowrp = null)
	wrp = Wrp.fromValue(@v, @onError, @vtowrp)
	if wrp == null then return null
	return wrp.toRESPString
end function

// ???
command = function(parts)
	if parts isa string then parts = parts.split
	cmd = ArrayWrp.make
	for p in parts
		if not p isa Wrp then p = BlobStringWrp.fromData(p)
		cmd.pushValue p
	end for
	return cmd.toRESP
end function
