:- module(math, [vector/2, withinRange/3, add/3, scale/3, distance/3]).

vector(X, Y) :-
    number(X),
    number(Y).

withinRange(L, H, X) :-
    number(L),
    number(H),
    number(X),
    X >= L,
    X =< H.

add(X, Y, Z) :- 
    number(X),
    number(Y),
    Z is X + Y.

add(vector(X1, Y1), vector(X2, Y2), vector(Xr, Yr)) :-
    Xr is X1 + X2,
    Yr is Y1 + Y2.

sub(X, Y, Z) :-
    number(X),
    number(Y),
    Z is X - Y.

sub(vector(X1, Y1), vector(X2, Y2), vector(Xr, Yr)) :-
    Xr is X1 - X2,
    Yr is Y1 - Y2.

scale(vector(X1,Y1), Factor, vector(Xr, Yr)) :-
    number(Factor),
    Xr is X1 * Factor,
    Yr is Y1 * Factor.

magnitude(vector(X,Y), M) :-
    M is sqrt(X*X + Y*Y).

distance(V1, V2, D) :-
    sub(V1, V2, Vr),
    magnitude(Vr, D).

normalize(V, Vn) :-
    magnitude(V, D),
    InvD is 1/D,
    scale(V, InvD, Vn).