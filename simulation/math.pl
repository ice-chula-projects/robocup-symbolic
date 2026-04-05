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

scale(vector(X1,Y1), Factor, vector(Xr, Yr)) :-
    number(Factor),
    Xr is X1 * Factor,
    Yr is Y1 * Factor.

distance(vector(X1, Y1), vector(X2, Y2), D) :-
    Dx is X1 - X2,
    Dy is Y1 - Y2,
    D is sqrt(Dx*Dx + Dy*Dy).