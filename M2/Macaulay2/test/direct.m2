M = ZZ^6
N = directSum {M}
P = directSum {M}
assert( M === N )					    -- changed this test, Jan 15, 2004
assert( N === P )
assert( directSum{M,N} === directSum{M,N} )
-- Local Variables:
-- compile-command: "make -C $M2BUILDDIR/Macaulay2/test direct.okay "
-- End:
