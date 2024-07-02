ensureImport "qa"
ensureImport "resp"

globals.str = @resp.str




// Tests for utils

testRefIndexOf = function
	a = {}
	qa.assertEqual resp.refIndexOf([], a), null
	qa.assertEqual resp.refIndexOf([a], a), 0
	qa.assertEqual resp.refIndexOf([{}, {}, a], a), 2
	qa.assertEqual resp.refIndexOf([{}, {}], a), null
end function

testMapGet = function
	qa.assertEqual resp.mapGet({}, "foo"), null
	qa.assertEqual resp.mapGet({}, "foo", 42), 42
	qa.assertEqual resp.mapGet({"foo": 420}, "foo", 42), 420
	qa.assertEqual resp.mapGet({"__isa": {"foo": 420}}, "foo", 42), 420
	qa.assertEqual resp.mapGet({"__isa": {"__isa": {"foo": 420}}}, "foo", 42), 420
end function

testMapSetDefault = function
	m = {}
	x = resp.mapSetDefault(m, "foo", "bar")
	qa.assertEqual x, "bar"
	qa.assertEqual m, {"foo": "bar"}
	x = resp.mapSetDefault(m, "foo", "baz")
	qa.assertEqual x, "bar"
	qa.assertEqual m, {"foo": "bar"}
end function

testStr = function
	str = @resp.str
	f = function(a, b) ; end function
	
	qa.assertEqual str(null), ""
	qa.assertEqual str(42), "42"
	qa.assertEqual str("foo"), "foo"
	qa.assertEqual str(@f), "FUNCTION(a, b)"
	
	qa.assertEqual str([]), "[]"
	qa.assertEqual str([null, 42, "foo", @f]), "[null, 42, ""foo"", FUNCTION(a, b)]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]]), "[42, [43, [44, […(2)]]]]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], 2), "[42, [43, […(2)]]]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], 0), "[…(2)]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], -1), "[42, [43, [44, […(2)]]]]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], 1/0), "[42, [43, [44, […(2)]]]]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], 10), "[42, [43, [44, [45, [46, null]]]]]"
	
	qa.assertEqual str({}), "{}"
	qa.assertEqual str({null: "foo"}), "{null: ""foo""}"
	qa.assertEqual str({@f: @f}), "{FUNCTION(a, b): FUNCTION(a, b)}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}), "{42: {43: {44: {…(1)}}}}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, 2), "{42: {43: {…(1)}}}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, 0), "{…(1)}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, -1), "{42: {43: {44: {…(1)}}}}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, 1/0), "{42: {43: {44: {…(1)}}}}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, 10), "{42: {43: {44: {45: {46: null}}}}}"
	
	m = {}
	m._str = function(depth) ; return "foo" ; end function
	qa.assertEqual str(m), "foo"
	qa.assertEqual str(new m), "foo"
	qa.assertEqual str(new (new m)), "foo"
	
	A = {"_name": "A"}
	qa.assertEqual str(A), "A"
	qa.assertEqual str(new A), "{""__isa"": A}"
	qa.assertEqual str(new (new A)), "{""__isa"": {""__isa"": A}}"
	
	A = {"_name": "A"}
	A._repr = function(depth) ; return "foo" ; end function
	qa.assertEqual str(A), "A"
	qa.assertEqual str(new A), "A(foo)"
	qa.assertEqual str(new (new A)), "A(foo)"
	
	A = {"_name": "A"}
	A._id = "foo"
	qa.assertEqual str(A), "A"
	qa.assertEqual str(new A), "A(foo)"
	qa.assertEqual str(new (new A)), "A(foo)"
	
	m = {}
	m.get = "foo"
	qa.assertEqual str(m), "{""get"": ""foo""}"
end function

testStringToRawData = function
	qa.assertEqual resp.stringToRawData("hello world!").utf8, "hello world!"
	qa.assertEqual resp.stringToRawData("Привіт Світ!").utf8, "Привіт Світ!"
	qa.assertEqual resp.stringToRawData("こんにちは世界!").utf8, "こんにちは世界!"
end function

testRawDataToString = function
	r = new RawData
	qa.assertEqual resp.rawDataToString(r), ""
	
	r.resize 3
	r.setUtf8 0, "foo"
	qa.assertEqual resp.rawDataToString(r), "foo"
	
	r.resize 0
	qa.assertEqual resp.rawDataToString(r), ""
end function

testRawDataCmp = function
	stord = @resp.stringToRawData
	
	qa.assertEqual resp.rawDataCmp(stord(""), stord("")), 0
	qa.assertEqual resp.rawDataCmp(stord("A"), stord("")), 1
	qa.assertEqual resp.rawDataCmp(stord(""), stord("A")), -1
	qa.assertEqual resp.rawDataCmp(stord("A"), stord("A")), 0
	qa.assertEqual resp.rawDataCmp(stord("AA"), stord("A")), 1
	qa.assertEqual resp.rawDataCmp(stord("A"), stord("AA")), -1
	qa.assertEqual resp.rawDataCmp(stord("AA"), stord("AA")), 0
	qa.assertEqual resp.rawDataCmp(stord("AB"), stord("AA")), 1
	qa.assertEqual resp.rawDataCmp(stord("AB"), stord("BA")), -1
end function




// Tests for RawDataCollection

testRawDataCollection = function
	stord = @resp.stringToRawData
	
	r = resp.RawDataCollection.make
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 0
	qa.assertEqual r.toRawData.len, 0
	
	r.push stord("foo")
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 3
	qa.assertEqual r.toRawData.utf8, "foo"
	
	r.advance 1
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 2
	qa.assertEqual r.toRawData.utf8, "oo"
	
	r.push "bar"
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 5
	qa.assertEqual r.toRawData.utf8, "oobar"
	
	r.grow -1
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 4
	qa.assertEqual r.toRawData.utf8, "ooba"
	
	r.push stord("baz")
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 7
	qa.assertEqual r.toRawData.utf8, "oobarba"
	
	r.push stord("bamf"), true
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 7
	qa.assertEqual r.toRawData.utf8, "oobarba"
	
	r.grow 1/0
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 12
	qa.assertEqual r.toRawData.utf8, "oobarbazbamf"
	
	r.grow -3
	rdl = r.toRawDataList
	qa.assertEqual rdl.len, 4
	qa.assertEqual rdl[0].utf8, "oo"
	qa.assertEqual rdl[1].utf8, "bar"
	qa.assertEqual rdl[2].utf8, "baz"
	qa.assertEqual rdl[3].utf8, "b"
end function

testRawDataCollectionTotalBytes = function
	stord = @resp.stringToRawData
	
	r = resp.RawDataCollection.make
	qa.assertEqual r.len, 0
	qa.assertEqual r.totalBytes, 0
	
	r.push "hello"
	qa.assertEqual r.len, 5
	qa.assertEqual r.totalBytes, 5
	
	r.advance 1
	qa.assertEqual r.len, 4
	qa.assertEqual r.totalBytes, 5
	
	r.grow -1
	qa.assertEqual r.len, 3
	qa.assertEqual r.totalBytes, 5
	
	r.push "world"
	qa.assertEqual r.len, 8
	qa.assertEqual r.totalBytes, 10
	
	r2 = resp.RawDataCollection.make
	r2.push "foo"
	r2.push r
	r2.push "bar"
	qa.assertEqual r2.len, 3 + 8 + 3
	qa.assertEqual r2.totalBytes, 3 + 8 + 3
end function

testRawDataCollectionPush = function
	r = resp.RawDataCollection.make
	
	v = "foo"
	r.push v
	qa.assertEqual r.toRawData.utf8, "foo"
	
	v = new RawData
	v.resize 3
	v.setUtf8 0, "bar"
	r.push v
	qa.assertEqual r.toRawData.utf8, "foobar"
	
	v = resp.RawDataCollection.make
	v.push "/bamf/"
	v.grow -1
	v.advance 1
	r.push v
	qa.assertEqual r.toRawData.utf8, "foobarbamf"
	
	v = "boo"
	r.push v, true
	qa.assertEqual r.toRawData.utf8, "foobarbamf"
	
	v = "far"
	r.push v
	qa.assertEqual r.toRawData.utf8, "foobarbamfboo"
end function

testRawDataCollectionTailBytes = function
	r = resp.RawDataCollection.make
	r.push "foo"
	r.push "bar", true
	qa.assertEqual r.tailBytes, 3
	
	r.grow 1
	qa.assertEqual r.tailBytes, 2
	
	r.grow -2
	qa.assertEqual r.tailBytes, 4
	
	r.grow 1/0
	qa.assertEqual r.tailBytes, 0
	
	r.advance 1
	r.grow -1
	qa.assertEqual r.tailBytes, 1
end function

testRawDataCollectionAdvance = function
	r = resp.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	qa.assertEqual r.toRawData.utf8, "foobar"
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 6
	qa.assertEqual r.totalBytes, 6
	
	r.advance 1
	qa.assertEqual r.toRawData.utf8, "oobar"
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 5
	qa.assertEqual r.totalBytes, 6
	
	r.advance 2
	qa.assertEqual r.toRawData.utf8, "bar"
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 3
	qa.assertEqual r.totalBytes, 3
	
	r.advance -1
	qa.assertEqual r.toRawData.utf8, "bar"
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 3
	qa.assertEqual r.totalBytes, 3
	
	r.grow -1
	qa.assertEqual r.toRawData.utf8, "ba"
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 2
	qa.assertEqual r.totalBytes, 3
	
	r.advance 2
	qa.assertEqual r.toRawData.len, 0
	qa.assertEqual r.offset, 2
	qa.assertEqual r.len, 0
	qa.assertEqual r.totalBytes, 3
end function

testRawDataCollectionGrow = function
	r = resp.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	
	r.grow -1
	qa.assertEqual r.len, 5
	qa.assertEqual r.toRawData.utf8, "fooba"
	
	r.grow -3
	qa.assertEqual r.len, 2
	qa.assertEqual r.toRawData.utf8, "fo"
	
	r.grow 100
	qa.assertEqual r.len, 6
	qa.assertEqual r.toRawData.utf8, "foobar"
	
	r.grow -1/0
	qa.assertEqual r.len, 0
	qa.assertEqual r.toRawData.len, 0
	
	r.grow 1
	qa.assertEqual r.len, 1
	qa.assertEqual r.toRawData.utf8, "f"
	
	r.advance 2
	qa.assertEqual r.len, 0
	qa.assertEqual r.toRawData.len, 0
	
	r.grow 3
	qa.assertEqual r.len, 3
	qa.assertEqual r.toRawData.utf8, "oba"
end function

testRawDataCollectionToRawData = function
	r = resp.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	
	v = resp.RawDataCollection.make
	v.push "baz"
	v.push "bamf"
	v.advance 1
	v.grow -1
	r.push v
	
	r.push "hello"
	qa.assertEqual r.toRawData.utf8, "foobarazbamhello"
	
	r.advance 2
	r.grow -2
	qa.assertEqual r.toRawData.utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(-1).utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(0).utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(1).utf8, "barazbamhel"
	qa.assertEqual r.toRawData(2).utf8, "arazbamhel"
	qa.assertEqual r.toRawData(3).utf8, "razbamhel"
	qa.assertEqual r.toRawData(4).utf8, "azbamhel"
	qa.assertEqual r.toRawData(5).utf8, "zbamhel"
	qa.assertEqual r.toRawData(6).utf8, "bamhel"
	qa.assertEqual r.toRawData(7).utf8, "amhel"
	qa.assertEqual r.toRawData(8).utf8, "mhel"
	qa.assertEqual r.toRawData(9).utf8, "hel"
	qa.assertEqual r.toRawData(10).utf8, "el"
	qa.assertEqual r.toRawData(11).utf8, "l"
	qa.assertEqual r.toRawData(12).len, 0
	qa.assertEqual r.toRawData(13).len, 0
	qa.assertEqual r.toRawData(0, 99).utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(0, 12).utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(0, 11).utf8, "obarazbamhe"
	qa.assertEqual r.toRawData(0, 10).utf8, "obarazbamh"
	qa.assertEqual r.toRawData(0, 9).utf8, "obarazbam"
	qa.assertEqual r.toRawData(0, 8).utf8, "obarazba"
	qa.assertEqual r.toRawData(0, 7).utf8, "obarazb"
	qa.assertEqual r.toRawData(0, 6).utf8, "obaraz"
	qa.assertEqual r.toRawData(0, 5).utf8, "obara"
	qa.assertEqual r.toRawData(0, 4).utf8, "obar"
	qa.assertEqual r.toRawData(0, 3).utf8, "oba"
	qa.assertEqual r.toRawData(0, 2).utf8, "ob"
	qa.assertEqual r.toRawData(0, 1).utf8, "o"
	qa.assertEqual r.toRawData(0, 0).len, 0
	qa.assertEqual r.toRawData(0, -1).len, 0
	qa.assertEqual r.toRawData(5, 2).utf8, "zb"
end function

testRawDataCollectionToRawDataList = function
	r = resp.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	
	v = resp.RawDataCollection.make
	v.push "baz"
	v.push "bamf"
	v.advance 1
	v.grow -1
	r.push v
	
	r.push "hello"
	qa.assertEqual r.toRawData.utf8, "foobarazbamhello"
	
	r.advance 2
	r.grow -2
	
	rr = r.toRawDataList
	qa.assertEqual rr[0].utf8, "o"
	qa.assertEqual rr[1].utf8, "bar"
	qa.assertEqual rr[2].utf8, "az"
	qa.assertEqual rr[3].utf8, "bam"
	qa.assertEqual rr[4].utf8, "hel"
	
	rr = r.toRawDataList(2)
	qa.assertEqual rr[0].utf8, "ar"
	qa.assertEqual rr[1].utf8, "az"
	qa.assertEqual rr[2].utf8, "bam"
	qa.assertEqual rr[3].utf8, "hel"
	
	rr = r.toRawDataList(2, 6)
	qa.assertEqual rr[0].utf8, "ar"
	qa.assertEqual rr[1].utf8, "az"
	qa.assertEqual rr[2].utf8, "ba"
end function

testRawDataCollectionCopy = function
	r = resp.RawDataCollection.make
	r.push "foo"
	
	c = r.copy
	c.push "bar"
	c.advance 1
	
	qa.assertEqual r.toRawData.utf8, "foo"
	qa.assertEqual c.toRawData.utf8, "oobar"
end function

testRawDataCollectionIndexOf = function
	stord = @resp.stringToRawData
	
	r = resp.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	
	qa.assertEqual r.indexOf("o"), 1
	qa.assertEqual r.indexOf("ob"), 2
	qa.assertEqual r.indexOf("x"), null
	
	s = "fo"
	qa.assertEqual r.indexOf(stord(s)), 0
	
	r.push "baz"
	s = "a"
	qa.assertEqual r.indexOf(stord(s)), 4
	qa.assertEqual r.indexOf(stord(s), 4), 4  // in "bar"
	qa.assertEqual r.indexOf(stord(s), 5), 7  // in "baz"
	qa.assertEqual r.indexOf(stord(s), 8), null
end function



testBlobStringWrp = function
	stord = @resp.stringToRawData
	
	s = ""
	w = resp.BlobStringWrp.fromData(s)
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toRESP.utf8, "$0" + char(13) + char(10) +
	                              ""   + char(13) + char(10)
	w = resp.BlobStringWrp.fromData(stord(s))
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toRESP.utf8, "$0" + char(13) + char(10) +
	                              ""   + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.BlobStringWrp.fromData(r)
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toRESP.utf8, "$0" + char(13) + char(10) +
	                              ""   + char(13) + char(10)
	
	s = "foo"
	w = resp.BlobStringWrp.fromData(s)
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toRESP.utf8, "$3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10)
	w = resp.BlobStringWrp.fromData(stord(s))
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toRESP.utf8, "$3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.BlobStringWrp.fromData(r)
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toRESP.utf8, "$3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10)
end function

testSimpleStringWrp = function
	stord = @resp.stringToRawData
	
	s = ""
	w = resp.SimpleStringWrp.fromData(s)
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toString, ""
	qa.assertEqual w.toRESP.utf8, "+" + char(13) + char(10)
	w = resp.SimpleStringWrp.fromData(stord(s))
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toString, ""
	qa.assertEqual w.toRESP.utf8, "+" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.SimpleStringWrp.fromData(r)
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toString, ""
	qa.assertEqual w.toRESP.utf8, "+" + char(13) + char(10)
	
	s = "foo"
	w = resp.SimpleStringWrp.fromData(s)
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10)
	w = resp.SimpleStringWrp.fromData(stord(s))
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.SimpleStringWrp.fromData(r)
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10)
	
	s = "foo" + char(13) + char(10) + "bar"
	w = resp.SimpleStringWrp.fromData(s)
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10)
	w = resp.SimpleStringWrp.fromData(stord(s))
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.SimpleStringWrp.fromData(r)
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10)
	
	s = "foo" + char(13) + char(10) + "bar"
	w = resp.SimpleStringWrp.fromData(s, true)
	qa.assertEqual w, null
	w = resp.SimpleStringWrp.fromData(stord(s), true)
	qa.assertEqual w, null
	r = resp.RawDataCollection.make
	r.push s
	w = resp.SimpleStringWrp.fromData(r, true)
	qa.assertEqual w, null
end function

testSimpleErrorWrp = function
	stord = @resp.stringToRawData
	
	s = ""
	w = resp.SimpleErrorWrp.fromData(s)
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toString, ""
	qa.assertEqual w.toRESP.utf8, "-" + char(13) + char(10)
	w = resp.SimpleErrorWrp.fromData(stord(s))
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toString, ""
	qa.assertEqual w.toRESP.utf8, "-" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.SimpleErrorWrp.fromData(r)
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toString, ""
	qa.assertEqual w.toRESP.utf8, "-" + char(13) + char(10)
	
	s = "foo"
	w = resp.SimpleErrorWrp.fromData(s)
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "-foo" + char(13) + char(10)
	w = resp.SimpleErrorWrp.fromData(stord(s))
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "-foo" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.SimpleErrorWrp.fromData(r)
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "-foo" + char(13) + char(10)
	
	s = "foo" + char(13) + char(10) + "bar"
	w = resp.SimpleErrorWrp.fromData(s)
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "-foo" + char(13) + char(10)
	w = resp.SimpleErrorWrp.fromData(stord(s))
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "-foo" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.SimpleErrorWrp.fromData(r)
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toString, "foo"
	qa.assertEqual w.toRESP.utf8, "-foo" + char(13) + char(10)
	
	s = "foo" + char(13) + char(10) + "bar"
	w = resp.SimpleErrorWrp.fromData(s, true)
	qa.assertEqual w, null
	w = resp.SimpleErrorWrp.fromData(stord(s), true)
	qa.assertEqual w, null
	r = resp.RawDataCollection.make
	r.push s
	w = resp.SimpleErrorWrp.fromData(r, true)
	qa.assertEqual w, null
end function

testNumberWrp = function
	stord = @resp.stringToRawData
	
	s = "0"
	w = resp.NumberWrp.fromData(s)
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "0"
	qa.assertEqual w.toString, "0"
	qa.assertEqual w.toNumber, 0
	qa.assertEqual w.toRESP.utf8, ":0" + char(13) + char(10)
	w = resp.NumberWrp.fromData(stord(s))
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "0"
	qa.assertEqual w.toString, "0"
	qa.assertEqual w.toNumber, 0
	qa.assertEqual w.toRESP.utf8, ":0" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.NumberWrp.fromData(r)
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "0"
	qa.assertEqual w.toString, "0"
	qa.assertEqual w.toNumber, 0
	qa.assertEqual w.toRESP.utf8, ":0" + char(13) + char(10)
	
	s = "123"
	w = resp.NumberWrp.fromData(s)
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "123"
	qa.assertEqual w.toString, "123"
	qa.assertEqual w.toNumber, 123
	qa.assertEqual w.toRESP.utf8, ":123" + char(13) + char(10)
	w = resp.NumberWrp.fromData(stord(s))
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "123"
	qa.assertEqual w.toString, "123"
	qa.assertEqual w.toNumber, 123
	qa.assertEqual w.toRESP.utf8, ":123" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.NumberWrp.fromData(r)
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "123"
	qa.assertEqual w.toString, "123"
	qa.assertEqual w.toNumber, 123
	qa.assertEqual w.toRESP.utf8, ":123" + char(13) + char(10)
	
	s = "-42.5"
	w = resp.NumberWrp.fromData(s)
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "-42"
	qa.assertEqual w.toString, "-42"
	qa.assertEqual w.toNumber, -42
	qa.assertEqual w.toRESP.utf8, ":-42" + char(13) + char(10)
	w = resp.NumberWrp.fromData(stord(s))
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "-42"
	qa.assertEqual w.toString, "-42"
	qa.assertEqual w.toNumber, -42
	qa.assertEqual w.toRESP.utf8, ":-42" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.NumberWrp.fromData(r)
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toRawData.utf8, "-42"
	qa.assertEqual w.toString, "-42"
	qa.assertEqual w.toNumber, -42
	qa.assertEqual w.toRESP.utf8, ":-42" + char(13) + char(10)
end function

testNullWrp = function
	w = resp.NullWrp.make
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.toRESP.utf8, "_" + char(13) + char(10)
	w = resp.NullWrp.make("_")
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.toRESP.utf8, "_" + char(13) + char(10)
	w = resp.NullWrp.make("$")
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.toRESP.utf8, "$-1" + char(13) + char(10)
	w = resp.NullWrp.make("*")
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.toRESP.utf8, "*-1" + char(13) + char(10)
end function

testDoubleWrp = function
	stord = @resp.stringToRawData
	
	s = "0"
	w = resp.DoubleWrp.fromData(s)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "0"
	qa.assertEqual w.toString, "0"
	qa.assertEqual w.toNumber, 0
	qa.assertEqual w.toRESP.utf8, ",0" + char(13) + char(10)
	w = resp.DoubleWrp.fromData(stord(s))
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "0"
	qa.assertEqual w.toString, "0"
	qa.assertEqual w.toNumber, 0
	qa.assertEqual w.toRESP.utf8, ",0" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.DoubleWrp.fromData(r)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "0"
	qa.assertEqual w.toString, "0"
	qa.assertEqual w.toNumber, 0
	qa.assertEqual w.toRESP.utf8, ",0" + char(13) + char(10)
	
	s = "-1.23e4"
	w = resp.DoubleWrp.fromData(s)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "-1.23e4"
	qa.assertEqual w.toString, "-1.23e4"
	qa.assertEqual w.toNumber, -1.23e4
	qa.assertEqual w.toRESP.utf8, ",-1.23e4" + char(13) + char(10)
	w = resp.DoubleWrp.fromData(stord(s))
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "-1.23e4"
	qa.assertEqual w.toString, "-1.23e4"
	qa.assertEqual w.toNumber, -1.23e4
	qa.assertEqual w.toRESP.utf8, ",-1.23e4" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.DoubleWrp.fromData(r)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "-1.23e4"
	qa.assertEqual w.toString, "-1.23e4"
	qa.assertEqual w.toNumber, -1.23e4
	qa.assertEqual w.toRESP.utf8, ",-1.23e4" + char(13) + char(10)
	
	s = "inf"
	w = resp.DoubleWrp.fromData(s)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "inf"
	qa.assertEqual w.toString, "inf"
	qa.assertEqual w.toNumber, 1/0
	qa.assertEqual w.toRESP.utf8, ",inf" + char(13) + char(10)
	w = resp.DoubleWrp.fromData(stord(s))
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "inf"
	qa.assertEqual w.toString, "inf"
	qa.assertEqual w.toNumber, 1/0
	qa.assertEqual w.toRESP.utf8, ",inf" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.DoubleWrp.fromData(r)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toRawData.utf8, "inf"
	qa.assertEqual w.toString, "inf"
	qa.assertEqual w.toNumber, 1/0
	qa.assertEqual w.toRESP.utf8, ",inf" + char(13) + char(10)
end function

testBooleanWrp = function
	stord = @resp.stringToRawData
	
	s = "t"
	w = resp.BooleanWrp.fromData(s)
	qa.assertEqual w isa resp.BooleanWrp, true
	qa.assertEqual w.toRawData.utf8, "t"
	qa.assertEqual w.toString, "t"
	qa.assertEqual w.toNumber, true
	qa.assertEqual w.toRESP.utf8, "#t" + char(13) + char(10)
	w = resp.BooleanWrp.fromData(stord(s))
	qa.assertEqual w isa resp.BooleanWrp, true
	qa.assertEqual w.toRawData.utf8, "t"
	qa.assertEqual w.toString, "t"
	qa.assertEqual w.toNumber, true
	qa.assertEqual w.toRESP.utf8, "#t" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.BooleanWrp.fromData(r)
	qa.assertEqual w isa resp.BooleanWrp, true
	qa.assertEqual w.toRawData.utf8, "t"
	qa.assertEqual w.toString, "t"
	qa.assertEqual w.toNumber, true
	qa.assertEqual w.toRESP.utf8, "#t" + char(13) + char(10)
	
	s = "f"
	w = resp.BooleanWrp.fromData(s)
	qa.assertEqual w isa resp.BooleanWrp, true
	qa.assertEqual w.toRawData.utf8, "f"
	qa.assertEqual w.toString, "f"
	qa.assertEqual w.toNumber, false
	qa.assertEqual w.toRESP.utf8, "#f" + char(13) + char(10)
	w = resp.BooleanWrp.fromData(stord(s))
	qa.assertEqual w isa resp.BooleanWrp, true
	qa.assertEqual w.toRawData.utf8, "f"
	qa.assertEqual w.toString, "f"
	qa.assertEqual w.toNumber, false
	qa.assertEqual w.toRESP.utf8, "#f" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.BooleanWrp.fromData(r)
	qa.assertEqual w isa resp.BooleanWrp, true
	qa.assertEqual w.toRawData.utf8, "f"
	qa.assertEqual w.toString, "f"
	qa.assertEqual w.toNumber, false
	qa.assertEqual w.toRESP.utf8, "#f" + char(13) + char(10)
end function

testBlobErrorWrp = function
	stord = @resp.stringToRawData
	
	s = ""
	w = resp.BlobErrorWrp.fromData(s)
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toRESP.utf8, "!0" + char(13) + char(10) +
	                              ""   + char(13) + char(10)
	w = resp.BlobErrorWrp.fromData(stord(s))
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toRESP.utf8, "!0" + char(13) + char(10) +
	                              ""   + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.BlobErrorWrp.fromData(r)
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toRawData.len, 0
	qa.assertEqual w.toRESP.utf8, "!0" + char(13) + char(10) +
	                              ""   + char(13) + char(10)
	
	s = "foo"
	w = resp.BlobErrorWrp.fromData(s)
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toRESP.utf8, "!3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10)
	w = resp.BlobErrorWrp.fromData(stord(s))
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toRESP.utf8, "!3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.BlobErrorWrp.fromData(r)
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toRawData.utf8, "foo"
	qa.assertEqual w.toRESP.utf8, "!3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10)
end function

testVerbatimStringWrp = function
	stord = @resp.stringToRawData
	
	s = ""
	w = resp.VerbatimStringWrp.fromFormatAndData("txt", s)
	qa.assertEqual w isa resp.VerbatimStringWrp, true
	qa.assertEqual w.toRawData.utf8, "txt:"
	qa.assertEqual w.toRESP.utf8, "=4"   + char(13) + char(10) +
	                              "txt:" + char(13) + char(10)
	w = resp.VerbatimStringWrp.fromFormatAndData("txt", stord(s))
	qa.assertEqual w isa resp.VerbatimStringWrp, true
	qa.assertEqual w.toRawData.utf8, "txt:"
	qa.assertEqual w.toRESP.utf8, "=4"   + char(13) + char(10) +
	                              "txt:" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.VerbatimStringWrp.fromFormatAndData("txt", r)
	qa.assertEqual w isa resp.VerbatimStringWrp, true
	qa.assertEqual w.toRawData.utf8, "txt:"
	qa.assertEqual w.toRESP.utf8, "=4"   + char(13) + char(10) +
	                              "txt:" + char(13) + char(10)
	
	s = "foo"
	w = resp.VerbatimStringWrp.fromFormatAndData("mkd", s)
	qa.assertEqual w isa resp.VerbatimStringWrp, true
	qa.assertEqual w.toRawData.utf8, "mkd:foo"
	qa.assertEqual w.toRESP.utf8, "=7"      + char(13) + char(10) +
	                              "mkd:foo" + char(13) + char(10)
	w = resp.VerbatimStringWrp.fromFormatAndData("mkd", stord(s))
	qa.assertEqual w isa resp.VerbatimStringWrp, true
	qa.assertEqual w.toRawData.utf8, "mkd:foo"
	qa.assertEqual w.toRESP.utf8, "=7"      + char(13) + char(10) +
	                              "mkd:foo" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.VerbatimStringWrp.fromFormatAndData("mkd", r)
	qa.assertEqual w isa resp.VerbatimStringWrp, true
	qa.assertEqual w.toRawData.utf8, "mkd:foo"
	qa.assertEqual w.toRESP.utf8, "=7"      + char(13) + char(10) +
	                              "mkd:foo" + char(13) + char(10)
end function

testBigNumberWrp = function
	stord = @resp.stringToRawData
	
	s = "3492890328409238509324850943850943825024385"
	w = resp.BigNumberWrp.fromData(s)
	qa.assertEqual w isa resp.BigNumberWrp, true
	qa.assertEqual w.toRawData.utf8, "3492890328409238509324850943850943825024385"
	qa.assertEqual w.toString, "3492890328409238509324850943850943825024385"
	qa.assertEqual w.toRESP.utf8, "(3492890328409238509324850943850943825024385" + char(13) + char(10)
	w = resp.BigNumberWrp.fromData(stord(s))
	qa.assertEqual w isa resp.BigNumberWrp, true
	qa.assertEqual w.toRawData.utf8, "3492890328409238509324850943850943825024385"
	qa.assertEqual w.toString, "3492890328409238509324850943850943825024385"
	qa.assertEqual w.toRESP.utf8, "(3492890328409238509324850943850943825024385" + char(13) + char(10)
	r = resp.RawDataCollection.make
	r.push s
	w = resp.BigNumberWrp.fromData(r)
	qa.assertEqual w isa resp.BigNumberWrp, true
	qa.assertEqual w.toRawData.utf8, "3492890328409238509324850943850943825024385"
	qa.assertEqual w.toString, "3492890328409238509324850943850943825024385"
	qa.assertEqual w.toRESP.utf8, "(3492890328409238509324850943850943825024385" + char(13) + char(10)
end function

testArrayWrp = function
	stord = @resp.stringToRawData
	
	w = resp.ArrayWrp.make
	qa.assertEqual w.elements, []
	qa.assertEqual w.toRESP.utf8, "*0" + char(13) + char(10)
	
	w.push resp.SimpleStringWrp.fromData("foo")
	qa.assertEqual w.elements[0].toString, "foo"
	qa.assertEqual w.toRESP.utf8, "*1"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10)
	
	w.push resp.BlobStringWrp.fromData("bar")
	qa.assertEqual w.elements[0].toString, "foo"
	qa.assertEqual w.elements[1].toRawData.utf8, "bar"
	qa.assertEqual w.toRESP.utf8, "*2"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "$3"   + char(13) + char(10) +
	                              "bar"  + char(13) + char(10)
	
	v = resp.ArrayWrp.make
	v.push resp.NumberWrp.fromData(42)
	v.push resp.BooleanWrp.fromData(true)
	w.push v
	w.push resp.NullWrp.make
	qa.assertEqual w.toRESP.utf8, "*4"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "$3"   + char(13) + char(10) +
	                              "bar"  + char(13) + char(10) +
	                              "*2"   + char(13) + char(10) +
	                              ":42"  + char(13) + char(10) +
	                              "#t"   + char(13) + char(10) +
	                              "_"    + char(13) + char(10)
	
	w = resp.ArrayWrp.make(true)
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10)
	
	w = resp.ArrayWrp.make(true, true)
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toRESP.utf8, "*?"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10)
	
	w = resp.ArrayWrp.make(true, false, true)
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "."    + char(13) + char(10)
	
	w = resp.ArrayWrp.make(true, true, true)
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toRESP.utf8, "*?"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "."    + char(13) + char(10)
end function

testMapWrp = function
	stord = @resp.stringToRawData
	
	w = resp.MapWrp.make
	qa.assertEqual w.elements, []
	qa.assertEqual w.toRESP.utf8, "%0" + char(13) + char(10)
	
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.BlobStringWrp.fromData("bar")]
	qa.assertEqual w.elements[0][0].toString, "foo"
	qa.assertEqual w.elements[0][1].toRawData.utf8, "bar"
	qa.assertEqual w.toRESP.utf8, "%1"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "$3"   + char(13) + char(10) +
	                              "bar"  + char(13) + char(10)
	
	v = resp.MapWrp.make
	v.push [resp.NumberWrp.fromData(42),
	        resp.BooleanWrp.fromData(true)]
	w.push [v,
	        resp.NullWrp.make]
	qa.assertEqual w.toRESP.utf8, "%2"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "$3"   + char(13) + char(10) +
	                              "bar"  + char(13) + char(10) +
	                              "%1"   + char(13) + char(10) +
	                              ":42"  + char(13) + char(10) +
	                              "#t"   + char(13) + char(10) +
	                              "_"    + char(13) + char(10)
	
	w = resp.MapWrp.make(true)
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10)
	
	w = resp.MapWrp.make(true, true)
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toRESP.utf8, "%?"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10)
	
	w = resp.MapWrp.make(true, false, true)
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "."    + char(13) + char(10)
	
	w = resp.MapWrp.make(true, true, true)
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toRESP.utf8, "%?"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "."    + char(13) + char(10)
end function

testSetWrp = function
	stord = @resp.stringToRawData
	
	w = resp.SetWrp.make
	qa.assertEqual w.elements, []
	qa.assertEqual w.toRESP.utf8, "~0" + char(13) + char(10)
	
	w.push resp.SimpleStringWrp.fromData("foo")
	qa.assertEqual w.elements[0].toString, "foo"
	qa.assertEqual w.toRESP.utf8, "~1"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10)
	
	w.push resp.BlobStringWrp.fromData("bar")
	qa.assertEqual w.elements[0].toString, "foo"
	qa.assertEqual w.elements[1].toRawData.utf8, "bar"
	qa.assertEqual w.toRESP.utf8, "~2"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "$3"   + char(13) + char(10) +
	                              "bar"  + char(13) + char(10)
	
	v = resp.SetWrp.make
	v.push resp.NumberWrp.fromData(42)
	v.push resp.BooleanWrp.fromData(true)
	w.push v
	w.push resp.NullWrp.make
	qa.assertEqual w.toRESP.utf8, "~4"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "$3"   + char(13) + char(10) +
	                              "bar"  + char(13) + char(10) +
	                              "~2"   + char(13) + char(10) +
	                              ":42"  + char(13) + char(10) +
	                              "#t"   + char(13) + char(10) +
	                              "_"    + char(13) + char(10)
	
	w = resp.SetWrp.make(true)
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10)
	
	w = resp.SetWrp.make(true, true)
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toRESP.utf8, "~?"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10)
	
	w = resp.SetWrp.make(true, false, true)
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "."    + char(13) + char(10)
	
	w = resp.SetWrp.make(true, true, true)
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toRESP.utf8, "~?"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "."    + char(13) + char(10)
end function

testAttributeWrp = function
	stord = @resp.stringToRawData
	
	w = resp.AttributeWrp.make
	qa.assertEqual w.elements, []
	qa.assertEqual w.toRESP.utf8, "|0" + char(13) + char(10)
	
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.BlobStringWrp.fromData("bar")]
	qa.assertEqual w.elements[0][0].toString, "foo"
	qa.assertEqual w.elements[0][1].toRawData.utf8, "bar"
	qa.assertEqual w.toRESP.utf8, "|1"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "$3"   + char(13) + char(10) +
	                              "bar"  + char(13) + char(10)
	
	v = resp.MapWrp.make
	v.push [resp.NumberWrp.fromData(42),
	        resp.BooleanWrp.fromData(true)]
	w.push [v,
	        resp.NullWrp.make]
	qa.assertEqual w.toRESP.utf8, "|2"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "$3"   + char(13) + char(10) +
	                              "bar"  + char(13) + char(10) +
	                              "%1"   + char(13) + char(10) +
	                              ":42"  + char(13) + char(10) +
	                              "#t"   + char(13) + char(10) +
	                              "_"    + char(13) + char(10)
	
	w = resp.AttributeWrp.make(true)
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10)
	
	w = resp.AttributeWrp.make(true, true)
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toRESP.utf8, "|?"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10)
	
	w = resp.AttributeWrp.make(true, false, true)
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toRESP.utf8, "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "."    + char(13) + char(10)
	
	w = resp.AttributeWrp.make(true, true, true)
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toRESP.utf8, "|?"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "."    + char(13) + char(10)
end function

testPushWrp = function
	stord = @resp.stringToRawData
	
	w = resp.PushWrp.make
	w.push resp.SimpleStringWrp.fromData("message")
	w.push resp.SimpleStringWrp.fromData("somechannel")
	w.push resp.SimpleStringWrp.fromData("this is the message")
	qa.assertEqual w.toRESP.utf8, ">3"                   + char(13) + char(10) +
	                              "+message"             + char(13) + char(10) +
	                              "+somechannel"         + char(13) + char(10) +
	                              "+this is the message" + char(13) + char(10)
end function

testStreamedStringWrp = function
	stord = @resp.stringToRawData
	
	w = resp.StreamedStringWrp.make
	w.push resp.BlobChunkWrp.fromData("foo")
	w.push resp.BlobChunkWrp.fromData("bar")
	qa.assertEqual w.toRawData.utf8, "foobar"
	qa.assertEqual w.toRESP.utf8, ";3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10) +
	                              ";3"  + char(13) + char(10) +
	                              "bar" + char(13) + char(10)
	
	w = resp.StreamedStringWrp.make(true)
	w.push resp.BlobChunkWrp.fromData("foo")
	w.push resp.BlobChunkWrp.fromData("bar")
	qa.assertEqual w.toRawData.utf8, "foobar"
	qa.assertEqual w.toRESP.utf8, "$?"  + char(13) + char(10) +
	                              ";3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10) +
	                              ";3"  + char(13) + char(10) +
	                              "bar" + char(13) + char(10)
	
	w = resp.StreamedStringWrp.make(false, true)
	w.push resp.BlobChunkWrp.fromData("foo")
	w.push resp.BlobChunkWrp.fromData("bar")
	qa.assertEqual w.toRawData.utf8, "foobar"
	qa.assertEqual w.toRESP.utf8, ";3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10) +
	                              ";3"  + char(13) + char(10) +
	                              "bar" + char(13) + char(10) +
	                              ";0"  + char(13) + char(10)
	
	w = resp.StreamedStringWrp.make(true, true)
	w.push "foo"
	w.push "bar"
	qa.assertEqual w.toRawData.utf8, "foobar"
	qa.assertEqual w.toRESP.utf8, "$?"  + char(13) + char(10) +
	                              ";3"  + char(13) + char(10) +
	                              "foo" + char(13) + char(10) +
	                              ";3"  + char(13) + char(10) +
	                              "bar" + char(13) + char(10) +
	                              ";0"  + char(13) + char(10)
end function

testValuesWrpSetAttribute = function
	a = resp.AttributeWrp.make
	a.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	
	w = resp.SimpleStringWrp.fromData("hello")
	w.setAttribute a
	qa.assertEqual w.attribute isa resp.AttributeWrp, true
	qa.assertEqual w.toRESP.utf8, "|1"     + char(13) + char(10) +
	                              "+foo"   + char(13) + char(10) +
	                              "+bar"   + char(13) + char(10) +
	                              "+hello" + char(13) + char(10)
	
	w = resp.BlobStringWrp.fromData("hello")
	w.setAttribute a
	qa.assertEqual w.attribute isa resp.AttributeWrp, true
	qa.assertEqual w.toRESP.utf8, "|1"    + char(13) + char(10) +
	                              "+foo"  + char(13) + char(10) +
	                              "+bar"  + char(13) + char(10) +
	                              "$5"    + char(13) + char(10) +
	                              "hello" + char(13) + char(10)
	
	w = resp.ArrayWrp.make
	w.push resp.NumberWrp.fromData(100)
	w.push resp.NumberWrp.fromData(200)
	w.setAttribute a
	qa.assertEqual w.attribute isa resp.AttributeWrp, true
	qa.assertEqual w.toRESP.utf8, "|1"   + char(13) + char(10) +
	                              "+foo" + char(13) + char(10) +
	                              "+bar" + char(13) + char(10) +
	                              "*2"   + char(13) + char(10) +
	                              ":100" + char(13) + char(10) +
	                              ":200" + char(13) + char(10)
end function

testValueWrpFromValue = function
	w = resp.Wrp.fromValue(null)
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.toValue, null
	
	w = resp.Wrp.fromValue(42)
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toValue, 42
	
	w = resp.Wrp.fromValue(42.5)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue, 42.5
	
	w = resp.Wrp.fromValue(true)
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toValue, 1
	
	w = resp.Wrp.fromValue(1/0)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue, 1/0
	
	w = resp.Wrp.fromValue(-1/0)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue, -1/0
	
	w = resp.Wrp.fromValue(0/0)
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue != w.toValue, true
	
	w = resp.Wrp.fromValue("foo")
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toValue, "foo"
	
	w = resp.Wrp.fromValue("foo" + char(13) + char(10) + "bar")
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toValue.utf8, "foo" + char(13) + char(10) + "bar"
	
	w = resp.Wrp.fromValue(["foo", 42])
	qa.assertEqual w isa resp.ArrayWrp, true
	qa.assertEqual w.toValue, ["foo", 42]
	
	w = resp.Wrp.fromValue({"foo": 42})
	qa.assertEqual w isa resp.MapWrp, true
	qa.assertEqual w.toValue, {"foo": 42}
	
	r = new RawData
	r.resize 3
	r.setUtf8 0, "foo"
	w = resp.Wrp.fromValue(r)
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toValue.utf8, "foo"
end function

testValueWrpFromValueOnError = function
	errCode = null
	a1 = null
	_onError = function(errCode, a1)
		outer.errCode = errCode
		outer.a1 = a1
	end function
	
	f = function ; end function
	w = resp.Wrp.fromValue(@f, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "FROM_FUNC"
	qa.assertEqual a1, null
	
	x = []
	x.push x
	w = resp.Wrp.fromValue(x, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "FROM_CYCLES"
	qa.assertEqual a1, x
	
	A = {}
	a = new A
	w = resp.Wrp.fromValue(a, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "FROM_ARB_INSTANCE"
	qa.assertEqual a1, a
	
	r = new RawData
	r.resize
	w = resp.Wrp.fromValue(r._handle, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "FROM_ARB_TYPE"
	//qa.assertEqual a1, r._handle
end function

testValueWrpFromValueToRESPWrp = function
	A = {}
	A._toRESPWrp = function
		return resp.BlobErrorWrp.fromData("err")
	end function
	a = new A
	w = resp.Wrp.fromValue(a)
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toValue.utf8, "err"
end function

testValueWrpFromValueVtowrp = function
	A = {}
	v = ["foo", new A, 42]
	
	_vtowrp = function(v)
		if v isa string then return resp.BlobStringWrp.fromData(v)
		if v isa A then return resp.MapWrp.make
	end function
	
	w = resp.Wrp.fromValue(v, null, @_vtowrp)
	v2 = w.toValue
	qa.assertEqual v2[0].utf8, "foo"
	qa.assertEqual v2[1], {}
	qa.assertEqual v2[2], 42
end function

testWrpFromRESP = function
	s = "$3"  + char(13) + char(10) +
	    "foo" + char(13) + char(10)
	w = resp.Wrp.fromRESP(s)
	qa.assertEqual w.toValue.utf8, "foo"
	
	r = resp.stringToRawData(":42" + char(13) + char(10))
	w = resp.Wrp.fromRESP(r)
	qa.assertEqual w.toValue, 42
	
	r1 = resp.stringToRawData("+foo")
	r2 = resp.stringToRawData(char(13) + char(10))
	w = resp.Wrp.fromRESP([r1, r2])
	qa.assertEqual w.toValue, "foo"
	
	rdcol = resp.RawDataCollection.make
	rdcol.push ",3.14"
	rdcol.push char(13) + char(10)
	w = resp.Wrp.fromRESP(rdcol)
	qa.assertEqual w.toValue, 3.14
end function

testWrpFromRESPOffset = function
	s = "xxxxx" +
	    "$3"    + char(13) + char(10) +
	    "foo"   + char(13) + char(10)
	w = resp.Wrp.fromRESP(s, 5)
	qa.assertEqual w.toValue.utf8, "foo"
	
	
	o = null
	
	_onError = function(errCode, a1, a2, offset)
		if errCode == "MORE_DATA" then
			outer.o = offset
			return a1
		end if
	end function
	s = "$3"    + char(13) + char(10) +
	    "foo"   + char(13) + char(10) +
	    "$3"    + char(13) + char(10) +
	    "bar"   + char(13) + char(10)
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w.toValue.utf8, "foo"
	w = resp.Wrp.fromRESP(s, o, @_onError)
	qa.assertEqual w.toValue.utf8, "bar"
end function

testWrpFromRESPOnError = function
	errCode = null
	a1 = null
	a2 = null
	offset = null
	_onError = function(errCode, a1, a2, offset)
		outer.errCode = errCode
		outer.a1 = a1
		outer.a2 = a2
		outer.offset = offset
	end function
	
	s = ""
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "NOT_ENOUGH_DATA"
	qa.assertEqual a1, null
	qa.assertEqual a2, null
	qa.assertEqual offset, 0
	
	s = "@foo"
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "UNKNOWN_TYPE"
	qa.assertEqual a1, "@"
	qa.assertEqual a2, 64
	qa.assertEqual offset, 0
	
	s = "+foo"
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "NOT_ENOUGH_DATA"
	qa.assertEqual a1, null
	qa.assertEqual a2, null
	qa.assertEqual offset, 1
	
	s = "$" + char(13) + char(10)
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "EMPTY_LENGTH"
	qa.assertEqual a1, null
	qa.assertEqual a2, null
	qa.assertEqual offset, 1
	
	s = "!?" + char(13) + char(10)
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "UNKNOWN_TYPE"
	qa.assertEqual a1, "!"
	qa.assertEqual a2, 33
	qa.assertEqual offset, 0
	
	s = "$3" + char(13) + char(10)
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "NOT_ENOUGH_DATA"
	qa.assertEqual a1, null
	qa.assertEqual a2, null
	qa.assertEqual offset, 4
	
	s = "$3" + char(13) + char(10) +
	    "foo"
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "NOT_ENOUGH_DATA"
	qa.assertEqual a1, null
	qa.assertEqual a2, null
	qa.assertEqual offset, 4
	
	s = "$3"  + char(13) + char(10) +
	    "foo" + "XX"
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "BAD_CHUNK"
	qa.assertEqual a1, 3
	qa.assertEqual a2, null
	qa.assertEqual offset, 4
	
	s = "$3"  + char(13) + char(10) +
	    "foo" + char(13) + char(10) +
	    "xxx"
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "MORE_DATA"
	qa.assertEqual a1.toValue.utf8, "foo"
	qa.assertEqual a2, null
	qa.assertEqual offset, 9
	
	s = "$?"  + char(13) + char(10) +
	    "+"
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "BAD_ELEM_TYPE"
	qa.assertEqual a1, "$"
	qa.assertEqual a2, "+"
	qa.assertEqual offset, 4
	
	s = "*?"  + char(13) + char(10) +
	    ";"
	w = resp.Wrp.fromRESP(s, null, @_onError)
	qa.assertEqual w, null
	qa.assertEqual errCode, "BAD_ELEM_TYPE"
	qa.assertEqual a1, "*"
	qa.assertEqual a2, ";"
	qa.assertEqual offset, 4
end function

testWrpToValue = function
	w = resp.BlobStringWrp.fromData("foo")
	qa.assertEqual w.toValue isa RawData, true
	qa.assertEqual w.toValue.utf8, "foo"
	
	w = resp.SimpleStringWrp.fromData("foo")
	qa.assertEqual w.toValue isa string, true
	qa.assertEqual w.toValue, "foo"
	
	w = resp.SimpleErrorWrp.fromData("foo")
	qa.assertEqual w.toValue isa string, true
	qa.assertEqual w.toValue, "foo"
	
	w = resp.NumberWrp.fromData("123")
	qa.assertEqual w.toValue isa number, true
	qa.assertEqual w.toValue, 123
	
	w = resp.NullWrp.make
	qa.assertEqual w.toValue, null
	
	w = resp.DoubleWrp.fromData("12.3")
	qa.assertEqual w.toValue isa number, true
	qa.assertEqual w.toValue, 12.3
	
	w = resp.BooleanWrp.fromData("t")
	qa.assertEqual w.toValue isa number, true
	qa.assertEqual w.toValue, true
	
	w = resp.BlobErrorWrp.fromData("foo")
	qa.assertEqual w.toValue isa RawData, true
	qa.assertEqual w.toValue.utf8, "foo"
	
	w = resp.VerbatimStringWrp.fromData("mkd:foo")
	qa.assertEqual w.toValue isa RawData, true
	qa.assertEqual w.toValue.utf8, "mkd:foo"
	
	w = resp.BigNumberWrp.fromData("1234")
	qa.assertEqual w.toValue isa number, true
	qa.assertEqual w.toValue, 1234
	
	w = resp.ArrayWrp.make
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toValue isa list, true
	qa.assertEqual w.toValue, ["foo", "bar"]
	
	w = resp.MapWrp.make
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toValue isa map, true
	qa.assertEqual w.toValue, {"foo": "bar"}
	
	w = resp.SetWrp.make
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toValue isa map, true
	qa.assertEqual w.toValue, {"foo": true, "bar": true}
	
	w = resp.AttributeWrp.make
	w.push [resp.SimpleStringWrp.fromData("foo"),
	        resp.SimpleStringWrp.fromData("bar")]
	qa.assertEqual w.toValue isa map, true
	qa.assertEqual w.toValue, {"foo": "bar"}
	
	w = resp.PushWrp.make
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleStringWrp.fromData("bar")
	qa.assertEqual w.toValue isa list, true
	qa.assertEqual w.toValue, ["foo", "bar"]
	
	w = resp.StreamedStringWrp.make
	w.push resp.BlobChunkWrp.fromData("foo")
	w.push resp.BlobChunkWrp.fromData("bar")
	qa.assertEqual w.toValue isa RawData, true
	qa.assertEqual w.toValue.utf8, "foobar"
end function

testWrpToValueWrptov = function
	w = resp.ArrayWrp.make
	w.push resp.SimpleStringWrp.fromData("foo")
	w.push resp.SimpleErrorWrp.fromData("bar")
	
	_wrptov = function(wrp)
		if wrp isa resp.SimpleStringWrp then return "/" + wrp.toString + "/"
	end function
	qa.assertEqual w.toValue(@_wrptov), ["/foo/", "bar"]
	
	_wrptov = function(wrp)
		if wrp isa resp.SimpleErrorWrp then return "/" + wrp.toString + "/"
	end function
	qa.assertEqual w.toValue(@_wrptov), ["foo", "/bar/"]
	
	_wrptov = function(wrp)
		if wrp isa resp.SimpleValueWrp then return "/" + wrp.toString + "/"
	end function
	qa.assertEqual w.toValue(@_wrptov), ["/foo/", "/bar/"]
end function

testWrpToRESPXxx = function
	
	w = resp.BlobStringWrp.fromData("foo")
	x = w.toRESP
	qa.assertEqual x isa RawData, true
	qa.assertEqual x.utf8, "$3"  + char(13) + char(10) +
	                       "foo" + char(13) + char(10)
	x = w.toRESPList
	qa.assertEqual x isa list, true
	for e in x ; qa.assertEqual e isa RawData, true ; end for
	qa.assertEqual resp.RawDataCollection.make(x).toRawData.utf8, "$3"  + char(13) + char(10) +
	                                                              "foo" + char(13) + char(10)
	x = w.toRESPString
	qa.assertEqual x isa string, true
	qa.assertEqual x, "$3"  + char(13) + char(10) +
	                  "foo" + char(13) + char(10)
	x = w.toRESPCollection
	qa.assertEqual x isa resp.RawDataCollection, true
	qa.assertEqual x.toRawData.utf8, "$3"  + char(13) + char(10) +
	                                 "foo" + char(13) + char(10)
	
	w = resp.SimpleStringWrp.fromData("foo")
	x = w.toRESP
	qa.assertEqual x isa RawData, true
	qa.assertEqual x.utf8, "+foo" + char(13) + char(10)
	x = w.toRESPList
	qa.assertEqual x isa list, true
	for e in x ; qa.assertEqual e isa RawData, true ; end for
	qa.assertEqual resp.RawDataCollection.make(x).toRawData.utf8, "+foo" + char(13) + char(10)
	x = w.toRESPString
	qa.assertEqual x isa string, true
	qa.assertEqual x, "+foo" + char(13) + char(10)
	x = w.toRESPCollection
	qa.assertEqual x isa resp.RawDataCollection, true
	qa.assertEqual x.toRawData.utf8, "+foo" + char(13) + char(10)
	
	
	// no... lazy...
	
	
end function



testLoaderBlobString = function
	l = resp.Loader.make
	l.push "$0" + char(13) + char(10) +
	       ""   + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toValue.len, 0
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "$3"  + char(13) + char(10)
	l.push "foo" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toValue.utf8, "foo"
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "$-1" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.typeCharacter, "$"
	qa.assertEqual l.getWrp, null
end function

testLoaderStreamedString = function
	l = resp.Loader.make
	l.push "$?" + char(13) + char(10) +
	       ";0" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.StreamedStringWrp, true
	qa.assertEqual w.toValue.len, 0
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "$?"  + char(13) + char(10)
	l.push ";3"  + char(13) + char(10)
	l.push "foo" + char(13) + char(10)
	l.push ";3"  + char(13) + char(10)
	l.push "bar" + char(13) + char(10)
	l.push ";0"  + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.StreamedStringWrp, true
	qa.assertEqual w.toValue.utf8, "foobar"
	qa.assertEqual l.getWrp, null
end function

testLoaderParts = function
	l = resp.Loader.make
	
	l.push "$"
	w = l.getWrp
	qa.assertEqual w, null
	
	l.push "3" + char(13)
	w = l.getWrp
	qa.assertEqual w, null
	
	l.push char(10) + "fo"
	w = l.getWrp
	qa.assertEqual w, null
	
	l.push "o" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BlobStringWrp, true
	qa.assertEqual w.toValue.utf8, "foo"
end function

testLoaderSimpleString = function
	l = resp.Loader.make
	l.push "+" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toValue, ""
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "+foo"
	l.push char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.SimpleStringWrp, true
	qa.assertEqual w.toValue, "foo"
	qa.assertEqual l.getWrp, null
end function

testLoaderSimpleError = function
	l = resp.Loader.make
	l.push "-" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toValue, ""
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "-foo"
	l.push char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.SimpleErrorWrp, true
	qa.assertEqual w.toValue, "foo"
	qa.assertEqual l.getWrp, null
end function

testLoaderNumber = function
	l = resp.Loader.make
	l.push ":0" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toValue, 0
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push ":123"
	l.push char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.NumberWrp, true
	qa.assertEqual w.toValue, 123
	qa.assertEqual l.getWrp, null
end function

testLoaderNull = function
	l = resp.Loader.make
	l.push "_" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.toValue, null
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "$-1" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.toValue, null
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "*-1" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.NullWrp, true
	qa.assertEqual w.toValue, null
	qa.assertEqual l.getWrp, null
end function

testLoaderDouble = function
	l = resp.Loader.make
	l.push ",0" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue, 0
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push ",12.3"
	l.push char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue, 12.3
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push ",-1.2e+3"
	l.push char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue, -1200
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push ",nan" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue != w.toValue, true
	qa.assertEqual l.getWrp, null
end function

testLoaderBoolean = function
	l = resp.Loader.make
	l.push "#t" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BooleanWrp, true
	qa.assertEqual w.toValue, true
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "#f"
	l.push char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BooleanWrp, true
	qa.assertEqual w.toValue, false
	qa.assertEqual l.getWrp, null
end function

testLoaderBlobError = function
	l = resp.Loader.make
	l.push "!0" + char(13) + char(10) +
	       ""   + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toValue.len, 0
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "!3"  + char(13) + char(10) +
	       "foo" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BlobErrorWrp, true
	qa.assertEqual w.toValue.utf8, "foo"
	qa.assertEqual l.getWrp, null
end function

testLoaderVerbatimString = function
	l = resp.Loader.make
	l.push "=4"   + char(13) + char(10) +
	       "txt:" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.VerbatimStringWrp, true
	qa.assertEqual w.toValue.utf8, "txt:"
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "=7"      + char(13) + char(10) +
	       "mkd:foo" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.VerbatimStringWrp, true
	qa.assertEqual w.toValue.utf8, "mkd:foo"
	qa.assertEqual l.getWrp, null
end function

testLoaderBigNumber = function
	l = resp.Loader.make
	l.push "(3492890328409238509324850943850943825024385" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BigNumberWrp, true
	qa.assertEqual w.toString, "3492890328409238509324850943850943825024385"
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "(3492890328409238509324850943850943825024385"
	l.push char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.BigNumberWrp, true
	qa.assertEqual w.toString, "3492890328409238509324850943850943825024385"
	qa.assertEqual l.getWrp, null
end function

testLoaderArray = function
	l = resp.Loader.make
	l.push "*0" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.ArrayWrp, true
	qa.assertEqual w.toValue, []
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "*2"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.ArrayWrp, true
	qa.assertEqual w.toValue, ["foo", 42]
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "*?"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	l.push "."    + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.ArrayWrp, true
	qa.assertEqual w.toValue, ["foo", 42]
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "*2"   + char(13) + char(10)
	l.push "*2"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	l.push "+bar" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.ArrayWrp, true
	qa.assertEqual w.toValue, [["foo", 42], "bar"]
	qa.assertEqual l.getWrp, null
end function

testLoaderMap = function
	l = resp.Loader.make
	l.push "%0" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.MapWrp, true
	qa.assertEqual w.toValue, {}
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "%1"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.MapWrp, true
	qa.assertEqual w.toValue, {"foo": 42}
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "%?"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	l.push "."    + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.MapWrp, true
	qa.assertEqual w.toValue, {"foo": 42}
	qa.assertEqual l.getWrp, null
end function

testLoaderSet = function
	l = resp.Loader.make
	l.push "~0" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.SetWrp, true
	qa.assertEqual w.toValue, {}
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "~2"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.SetWrp, true
	qa.assertEqual w.toValue, {"foo": true, 42: true}
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "~?"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	l.push "."    + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.SetWrp, true
	qa.assertEqual w.toValue, {"foo": true, 42: true}
	qa.assertEqual l.getWrp, null
end function

testLoaderPush = function
	l = resp.Loader.make
	l.push ">3"                   + char(13) + char(10) +
	       "+message"             + char(13) + char(10) +
	       "+somechannel"         + char(13) + char(10) +
	       "+this is the message" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.PushWrp, true
	qa.assertEqual w.toValue, ["message", "somechannel", "this is the message"]
	qa.assertEqual l.getWrp, null
end function

testValuesWithAttributes = function
	l = resp.Loader.make
	l.push "|1"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	l.push ",3.14" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.DoubleWrp, true
	qa.assertEqual w.toValue, 3.14
	qa.assertEqual w.attribute isa resp.AttributeWrp, true
	qa.assertEqual w.attribute.toValue, {"foo": 42}
	qa.assertEqual l.getWrp, null
	
	l = resp.Loader.make
	l.push "|1"   + char(13) + char(10)
	l.push "+foo" + char(13) + char(10)
	l.push ":42"  + char(13) + char(10)
	l.push "*2"   + char(13) + char(10)
	l.push ":100" + char(13) + char(10)
	l.push "|1"   + char(13) + char(10)
	l.push "+bar" + char(13) + char(10)
	l.push ":43"  + char(13) + char(10)
	l.push ":200" + char(13) + char(10)
	w = l.getWrp
	qa.assertEqual w isa resp.ArrayWrp, true
	qa.assertEqual w.toValue, [100, 200]
	qa.assertEqual w.attribute isa resp.AttributeWrp, true
	qa.assertEqual w.attribute.toValue, {"foo": 42}
	qa.assertEqual w.elements[1].attribute isa resp.AttributeWrp, true
	qa.assertEqual w.elements[1].attribute.toValue, {"bar": 43}
	qa.assertEqual l.getWrp, null
end function

testLoaderStreamedEvents = function
	
	errArgs = null
	_onError = function(errCode, a1, a2, offset)
		if errCode[:6] == "STREAM" then outer.errArgs = [errCode, a1, a2, offset]
	end function
	
	l = resp.Loader.make
	l.push "$?" + char(13) + char(10)
	w = l.getWrp(@_onError)
	qa.assertEqual w, null
	qa.assertEqual errArgs[0], "STREAM_STARTED"
	qa.assertEqual errArgs[1].isStreamed, true
	qa.assertEqual errArgs[2], null
	qa.assertEqual errArgs[3], 4
	errArgs = null
	
	l.push ";3" + char(13) + char(10) +
	       "foo" + char(13) + char(10)
	w = l.getWrp(@_onError)
	qa.assertEqual w, null
	qa.assertEqual errArgs[0], "STREAM_ELEMENT"
	qa.assertEqual errArgs[1].isStreamed, true
	qa.assertEqual errArgs[2].toRawData.utf8, "foo"
	qa.assertEqual errArgs[3], 13
	errArgs = null
	
	l.push ";0" + char(13) + char(10)
	w = l.getWrp(@_onError)
	qa.assertEqual w.toValue.utf8, "foo"
	qa.assertEqual errArgs[0], "STREAM_STOPPED"
	qa.assertEqual errArgs[1].isStreamed, true
	qa.assertEqual errArgs[2], null
	qa.assertEqual errArgs[3], 17
	errArgs = null
end function



testLoad = function
	s = "$3"  + char(13) + char(10) +
	    "foo" + char(13) + char(10)
	v = resp.load(s)
	qa.assertEqual v isa RawData, true
	qa.assertEqual v.utf8, "foo"
	
	r = resp.stringToRawData(
	    "+bar" + char(13) + char(10))
	v = resp.load(r)
	qa.assertEqual v isa string, true
	qa.assertEqual v, "bar"
	
	rr = [resp.stringToRawData(":42"),
	      resp.stringToRawData(char(13) + char(10))]
	v = resp.load(rr)
	qa.assertEqual v isa number, true
	qa.assertEqual v, 42
	
	x = resp.RawDataCollection.make(
	    [resp.stringToRawData(",4.2"),
	     resp.stringToRawData(char(13) + char(10))])
	v = resp.load(x)
	qa.assertEqual v isa number, true
	qa.assertEqual v, 4.2
end function

testLoadOffset = function
	s = "xxxxx" +
	    "$3"  + char(13) + char(10) +
	    "foo" + char(13) + char(10)
	v = resp.load(s, 5)
	qa.assertEqual v isa RawData, true
	qa.assertEqual v.utf8, "foo"
end function

testLoadOnError = function
	o = null
	
	_onError = function(errCode, a1, a2, offset)
		if errCode == "MORE_DATA" then
			outer.o = offset
			return a1
		end if
	end function
	
	s = "$3"   + char(13) + char(10) +
	    "foo"  + char(13) + char(10) +
	    "+bar" + char(13) + char(10)
	v = resp.load(s, o, @_onError)
	qa.assertEqual v isa RawData, true
	qa.assertEqual v.utf8, "foo"
	v = resp.load(s, o, @_onError)
	qa.assertEqual v isa string, true
	qa.assertEqual v, "bar"
end function

testLoadWrptov = function
	
	_wrptov = function(wrp)
		if wrp isa resp.BlobStringWrp then return "/" + wrp.toRawData.utf8 + "/"
	end function
	
	s = "$3"  + char(13) + char(10) +
	    "foo" + char(13) + char(10)
	v = resp.load(s, null, null, @_wrptov)
	qa.assertEqual v isa string, true
	qa.assertEqual v, "/foo/"
end function

testDump = function
	v = "foo"
	r = resp.dump(v)
	qa.assertEqual r.utf8, "+foo" + char(13) + char(10)
	
	v = 100
	r = resp.dump(v)
	qa.assertEqual r.utf8, ":100" + char(13) + char(10)
	
	v = ["foo", "bar"]
	r = resp.dump(v)
	qa.assertEqual r.utf8, "*2"   + char(13) + char(10) +
	                       "+foo" + char(13) + char(10) +
	                       "+bar" + char(13) + char(10)
end function

testDumpOnError = function
	c = null
	
	_onError = function(errCode, a1)
		outer.c = errCode
	end function
	
	v = []
	v.push v
	r = resp.dump(v, @_onError)
	qa.assertEqual r, null
	qa.assertEqual c, "FROM_CYCLES"
end function

testDumpVtowrp = function
	
	_vtowrp = function(v)
		if v isa string then return resp.VerbatimStringWrp.fromFormatAndData("txt", v)
	end function
	
	v = {"foo": 42}
	r = resp.dump(v, null, @_vtowrp)
	qa.assertEqual r.utf8, "%1"      + char(13) + char(10) +
	                       "=7"      + char(13) + char(10) +
	                       "txt:foo" + char(13) + char(10) +
	                       ":42"     + char(13) + char(10)
end function
