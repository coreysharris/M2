--		Copyright 1995-2002 by Daniel R. Grayson and Michael Stillman

koszul(ZZ, Matrix) := Matrix => (i,m) -> map(ring m, rawKoszul(i, raw m))

-- this seems not to be useful to the user (yet):
-- koszul(ZZ, Matrix, Matrix) := Matrix => (i,m,n) -> map(ring m, rawKoszulMonomials(i, raw m, raw n))

symmetricPower(ZZ, Matrix) := Matrix => (i,m) -> map(ring m, rawSymmetricPower(i, raw m))

MinorsComputation = new SelfInitializingType of BasicList
MinorsComputation.synonym = "minors computation"

getMinorsStrategy := (R,options) -> (
     bareiss := 0;  -- WARNING: these must match the engine!!
     cofactor := 1;
     strat := if options.?Strategy then options.Strategy else null;
     if strat === symbol Bareiss then bareiss
     else if strat === symbol Cofactor then cofactor
     else if strat =!= null then (
	  error "'Strategy' keyword must be 'Cofactor' or 'Bareiss'";
	  )
     else (
	  -- Use the Bareiss algorithm unless R is a quotient of
	  -- a polynomial ring.  Note that if R is non-commutative
	  -- then either algorithm is incorrect.  What is the correct
	  -- thing to do in this case?
	  if isQuotientRing R and not isField R then
     	    cofactor
	  else
	    bareiss
     ))

minors = method(Options => { Limit => infinity, First => null, Strategy => null })
exteriorPower = method(Options => { Strategy => null })
determinant = method(Options => { Strategy => null })

exteriorPower(ZZ,Module) := Module => options -> (p,M) -> (
     R := ring M;
     if p < 0 then R^0
     else if p === 0 then R^1
     else if p === 1 then M
     else (
	  if isFreeModule M then new Module from (R, rawExteriorPower(p,M.RawFreeModule))
	  else (
	       m := presentation M;
	       F := target m;
	       G := source m;
	       Fp1 := exteriorPower(p-1,F,options);
	       Fp := exteriorPower(p,F,options);
	       h1 := m ** id_Fp1;
	       h2 := wedgeProduct(1,p-1,F);
	       cokernel (h2*h1))))

exteriorPower(ZZ, Matrix) := Matrix => options -> (p,m) -> (
     R := ring m;
     if p < 0 then map(R^0,R^0,0)
     else if p === 0 then map(R^1,R^1,1)
     else if p === 1 then m
     else map(
	  exteriorPower(p, target m, options),
	  exteriorPower(p, source m, options),
	  rawExteriorPower(p,raw m,getMinorsStrategy(R,options))))

wedgeProduct = method()
wedgeProduct(ZZ,ZZ,Module) := Matrix => (p,q,M) -> (
     if isFreeModule M then map(ring M, rawWedgeProduct(p,q,raw M))
     else map(exteriorPower(p+q,M),exteriorPower(p,M)**exteriorPower(q,M),wedgeProduct(p,q,cover M)))

minors(ZZ,Matrix) := Ideal => opts -> (j,m) -> (
     f := opts.First;
     if not (
	  f === null or (
	       class f === List
	       and #f == 2
	       and all(f, s -> class s === List)
	       )
	  ) then error "expected a list of 2 lists of integers";
     ideal map(ring m, rawMinors(j, raw m, getMinorsStrategy(ring m,opts), 
	       if opts.Limit === infinity then -1 else opts.Limit,
	       if f =!= null then f#0, 
	       if f =!= null then f#1)))

pfaffians = method(TypicalValue => Ideal)
pfaffians(ZZ,Matrix) := Ideal => (j,m) -> (
     ideal(map(ring m, rawPfaffians(j,raw m))))

-----------------------------------------------------------------------------
trace Matrix := RingElement => f -> (
     if rank source f != rank target f
     or not isFreeModule source f
     or not isFreeModule target f
     then error "expected a square matrix";
     sum(rank source f, i -> f_(i,i)))
-----------------------------------------------------------------------------
determinant Matrix := RingElement => options -> f -> (
     if rank source f != rank target f
     or not isFreeModule source f
     or not isFreeModule target f
     then error "expected a square matrix";
     (exteriorPower(numgens source f, f, options))_(0,0))

fittingIdeal = method(TypicalValue => Ideal)
fittingIdeal(ZZ,Module) := Ideal => (i,M) -> (
     p := presentation M;
     n := rank target p;
     if n <= i
     then ideal 1_(ring M)
     else trim minors(n-i,p))


-- Local Variables:
-- compile-command: "make -C $M2BUILDDIR/Macaulay2/m2 "
-- End:
