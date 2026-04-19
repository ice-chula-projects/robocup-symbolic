:- module(math, [vector/2, withinRange/3, add/3, sub/3, scale/3, magnitude/2, distance/3, normalize/2, polar/2, toVector/2, toPolar/2, middle/3, dot/3, clamp/4, sign/2]).

% this file contains many predicates related to math

vector(X, Y) :-
    number(X),
    number(Y).

polar(r, theta) :-
    number(r),
    number(theta).

toVector(polar(R, Theta), vector(X,Y)) :-
    X is R * cos(Theta),
    Y is R * sin(Theta).

toPolar(vector(X,Y), polar(R, Theta)) :-
    magnitude(vector(X,Y), R),
    Theta is atan2(Y,X).

% checks if X is between L and H inclusive
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

% scales a vector by some factor
scale(vector(X1,Y1), Factor, vector(Xr, Yr)) :-
    number(Factor),
    Xr is X1 * Factor,
    Yr is Y1 * Factor.

magnitude(vector(X,Y), M) :-
    M is sqrt(X*X + Y*Y).

% pretends the 2 vectors are points and
% returns the distance between those 2 points
distance(V1, V2, D) :-
    sub(V1, V2, Vr),
    magnitude(Vr, D).

normalize(V, Vn) :-
    magnitude(V, D),
    InvD is 1/D,
    scale(V, InvD, Vn).

% Find the position at the middle of 2 vectors
middle(V1, V2, Middle) :-
    add(V1, V2, Added),
    scale(Added, 0.5, Middle).

% Dot product function = |Vector1| * |Vector2| * cos(Theta)
dot(vector(X1, Y1), vector(X2, Y2), DotProduct) :-
    DotProduct is (X1 * X2) + (Y1 * Y2).

% Clamps X within a range of Min and Max
clamp(X, Min, _, Min) :- X < Min, !.
clamp(X, _, Max, Max) :- X > Max, !.
clamp(X, _, _, X).

% Returns the sign of a number in the form of -1, 0, and +1.
sign(X, -1) :- X < 0, !.
sign(X, 0) :- X =:= 0, !.
sign(_, +1).