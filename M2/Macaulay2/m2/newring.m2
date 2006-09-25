-- Copyright 1996 Michael E. Stillman

----------------------------------
-- new polynomial ring from old --
----------------------------------

nothing := symbol nothing
mergeOptions := (x,y) -> merge(x, y, (a,b) -> if b === nothing then a else b)
modifyRing = method( Options => applyValues(monoidDefaults, x -> nothing) )

modifyRing Ring := Ring => options -> (R) -> (
     -- First check the type of ring of R
     -- The following is for the case when R is a polynomial ring,
     -- or a quotient of a polynomial ring

     if    (instance(options.Variables,List) 
              and #( options.Variables ) =!= numgens R)
        or (instance(options.Variables,ZZ) 
              and options.Variables =!= numgens R)
     then
         error "cannot change the number of variables using 'modifyRing'";
         
     options = mergeOptions((monoid R).Options,options);
     f := presentation R;
     A := ring f;
     k := coefficientRing A;
     S := k[options];
     f = substitute(f,vars S);
     S/image f
     )

-----------------------------
-- tensor product of rings --
-----------------------------

-- made a method and documented elsewhere.

tensor(Ring,Ring) := Ring ** Ring := Ring => (R,S) -> error "tensor product not implemented for these rings"

PolynomialRing ** PolynomialRing :=
QuotientRing ** PolynomialRing :=
PolynomialRing ** QuotientRing :=
QuotientRing ** QuotientRing := (R,S) -> tensor(R,S)

tensor(PolynomialRing, PolynomialRing) :=
tensor(QuotientRing, PolynomialRing) :=
tensor(PolynomialRing, QuotientRing) :=
tensor(QuotientRing, QuotientRing) := optns -> (R,S) -> (
     k := coefficientRing R;
     if k =!= coefficientRing S 
     then error "expected rings to have the same coefficient ring";
     f := presentation R; A := ring f; M := monoid A; m := numgens M;
     g := presentation S; B := ring g; N := monoid B; n := numgens N;
     AB := k tensor(M, N, 
	  MonomialSize => max((options M).MonomialSize, (options N).MonomialSize),
	  optns);
     fg := substitute(f,(vars AB)_{0 .. m-1}) | substitute(g,(vars AB)_{m .. m+n-1});
     -- forceGB fg;  -- if the monomial order chosen doesn't restrict, then this
                     -- is an error!! MES
     AB/image fg)

-------------------------
-- Graph of a ring map --
-------------------------

graphIdeal = method( Options => apply( {MonomialOrder, MonomialSize, VariableBaseName}, o -> o => monoidDefaults#o ))
graphRing = method( Options => options graphIdeal )

graphIdeal RingMap := Ideal => options -> (f) -> (
     -- return the ideal in the tensor product of the graph of f.
     -- if f is graded, then set the degrees correctly in the tensor ring.
     -- return the ideal (y_i - f_i : all i) in this ring.
     S := source f;
     R := target f;
     k := coefficientRing R;
     if not (
	  isAffineRing R
	  and isAffineRing S
	  and k === coefficientRing S
	  ) then error "expected polynomial rings over the same ring";
     if vars k ** R != f (vars k ** S)	  -- vars k isn't really enough...
     then error "expected ring map to be identity on coefficient ring";
     t := numgens S;
     h := submatrix(f.matrix,,toList(0 .. t - 1));
     options = new MutableHashTable from options;
     options.Degrees = join((monoid R).degrees, 
	  apply(degrees source h, d -> if d === {0} then {1} else d)
	  );
     options = new OptionTable from options;
     RS := tensor(R,S,options);
     --RS := tensor(R,S,
     --             Degrees=>join((monoid R).degrees, degrees source h),
     --             MonomialOrder=>Eliminate numgens R,
     --             options);
     yvars := (vars RS)_{numgens R .. numgens RS - 1};
     xvars := (vars RS)_{0..numgens R - 1};
     I := ideal(yvars - substitute(h, xvars));
     if debugLevel > 0 and isHomogeneous f then assert isHomogeneous I;
     I)

graphRing RingMap := QuotientRing => options -> (f) -> (
     if f.cache.?graphRing then f.cache.graphRing else f.cache.graphRing = (
     	  I := graphIdeal(f,options);
     	  R := ring I;
     	  R/I))

-----------------------
-- Symmetric Algebra --
-----------------------

symmetricAlgebraIdeal := method( Options => monoidDefaults )

symmetricAlgebra = method( Options => monoidDefaults )


symmetricAlgebraIdeal Module := Ideal => opts -> (M) -> (
     R := ring M;
     K := coefficientRing ultimate(ambient, R);
     m := presentation M;
     N := if opts.Variables === monoidDefaults.Variables
          then monoid[Variables => numgens M]
          else monoid[Variables => opts.Variables];
     SM := tensor(K N, R, opts, Variables => monoidDefaults.Variables);
     xvars := submatrix(vars SM, {numgens target m .. numgens SM - 1});
     yvars := submatrix(vars SM, {0 .. numgens target m - 1});
     m = substitute(m,xvars);
     I := yvars*m)

symmetricAlgebra Module := Ring => options -> (M) -> (
     I := symmetricAlgebraIdeal(M,options);
     if I == 0 then ring I else (ring I)/(image I))

-----------------------------------------------------------------------------
-- flattenRing
-----------------------------------------------------------------------------
-- Copyright 2006 by Daniel R. Grayson

-- flattening rings (like (QQ[a,b]/a^3)[x,y]/y^6 --> QQ[a,b,x,y]/(a^3,y^6)
flattenRing = method(
     Options => {					    -- return value = (new ring, ring map to it, ring map from it)
	  CoefficientRing => null			    -- the default is to take the latest (declared) field or basic ring in the list of base rings
	  })

unable := () -> error "unable to flatten ring over given coefficient ring"

-- in general, fraction fields are not finitely presented over smaller coefficient rings
-- maybe we'll do something later when we have localization as something more intrinsic
-- flattenRing FractionField := opts -> F -> ...

triv := R -> ( idR := map(R,R); (R,idR,idR) )

flattenRing Ring := opts -> R -> (
     if R.?isBasic or isField R or R === opts.CoefficientRing then triv R
     else unable())

flattenRing GaloisField := opts -> F -> flattenRing(ambient F, opts)

flattenRing PolynomialRing := opts -> R -> (
     A := coefficientRing R;
     M2 := monoid R;
     zerdeg := toList (degreeLength M2 : 0);
     n2 := numgens M2;
     if opts.CoefficientRing === A or opts.CoefficientRing === null and (isField A or A.?isBasic) then return triv R;
     if # generators R === 0 then return flattenRing(A,opts);
     (S',p,q) := flattenRing(coefficientRing R, opts);
     I := ideal S';
     S := ring I;
     if instance(S,PolynomialRing) then (
     	  k := coefficientRing S;
     	  M1 := monoid S;
     	  n1 := numgens M1;
     	  M := tensor(M2,M1, Degrees => degrees M2 | toList ( n1 : zerdeg));
     	  T := k M;
	  )
     else (
	  n1 = 0;
	  T = S M2;
	  );
     inc := map(T,S,(vars T)_(toList (n2 .. n2 + n1 - 1)), DegreeMap => d -> zerdeg);
     I' := inc I;
     T' := T/I';
     inc' := map(T',S', promote(matrix inc,T'), DegreeMap => d -> zerdeg);
     pr := map(T',T);
     p' := map(T',R, (vars T')_(toList (0 .. n2-1)) | inc' matrix p);
     q' := map(R,T', vars R | promote(matrix q,R));
     (T', p', q'))

flattenRing QuotientRing := opts -> R -> (
     if instance(ambient R, PolynomialRing) and (
	  k := coefficientRing R;
	  opts.CoefficientRing === null and (isField k or k.?isBasic)
	  or opts.CoefficientRing === k
	  )
     then return triv R;
     I := ideal R;
     A := ring I;
     (B',p,q) := flattenRing(A,opts);
     J := ideal B';
     B := ring J;
     J' := lift(p I, B);				    -- adds in J automatically
     S := B/J';
     p' := map(S,R, promote( lift( matrix p, B ), S ));
     q' := map(R,S, promote( matrix q, R ));
     (S, p', q'))

-- Local Variables:
-- compile-command: "make -C $M2BUILDDIR/Macaulay2/m2 "
-- End:
