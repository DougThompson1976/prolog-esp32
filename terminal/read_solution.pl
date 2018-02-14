
:- module(read_solution, [
	      read_solution/4   % +Stream, +Query, Constants, Structures
	  ]).

:- use_module(microcontroller_io).


read_solution(Stream, Query, Constants, Structures) :-
	setup_state(Empty_State, Constants, Structures),
	functor(Query, Name, Arity),
	length(Arguments, Arity),
	fetch_registers(Arguments, 1, Stream, Empty_State, State),
	fetch_values(State),
	compound_name_arguments(Query, Name, Arguments).


setup_state(State, Constants, Structures) :-
	state(State, Constants, Structures, [], []).


fetch_values(_).


fetch_registers([], _Register, _Stream, State, State).

fetch_registers([Value|Values], Xn, Stream) -->
	fetch_register(Value, Xn, Stream),
	{
	    Next_Xn is Xn + 1
	},
	fetch_registers(Values, Next_Xn, Stream).


fetch_register(Value, Xn, Stream, Current_State, New_State) :-
	read_register(Stream, Xn, Wrapped_Value),
	unwrap_value(Wrapped_Value, Value, Stream, Current_State, New_State).


fetch_heap_values([], _Register, _Stream, State, State).

fetch_heap_values([Value|Values], H, Stream) -->
	fetch_heap_value(Value, H, Stream),
	{
	    Next_H is H + 1
	},
	fetch_heap_values(Values, Next_H, Stream).


fetch_heap_value(Value, H, Stream, Current_State, New_State) :-
	read_memory(Stream, H, Wrapped_Value),
	unwrap_value(Wrapped_Value, Value, Stream, Current_State, New_State).


unwrap_value(reference(H), Value, _Stream, State, State) :-
	state(State, _, _, _, Discovered_Values),
	memberchk(H->Value, Discovered_Values),
	!.

unwrap_value(reference(H), Value, _Stream, Current_State, New_State) :-
	state(Current_State, Constants, Structures, Addresses_To_Read, Discovered_Values),
	state(New_State, Constants, Structures, Addresses_To_Read, [H->Value|Discovered_Values]).

unwrap_value(structure(H), Value, Stream, Current_State, New_State) :-
	state(Current_State, _, Structures, _, _),
	read_functor(Stream, H, Functor_ID, Arity),
	memberchk(Functor-Functor_ID, Structures),
	length(Arguments, Arity),
	First_Argument_H is H + 1,
	fetch_heap_values(Arguments, First_Argument_H, Stream, Current_State, New_State),
	compound_name_arguments(Value, Functor, Arguments).

unwrap_value(list(H), [Head|Tail], Stream, Current_State, New_State) :-
	fetch_heap_values([Head, Tail], H ,Stream, Current_State, New_State).

unwrap_value(constant(ID), C, _Stream, State, State) :-
	state(State, Constants, _, _, _),
	memberchk(C-ID, Constants).

unwrap_value(integer(I), I, _Stream, State, State).


state(state(Constants, Structures, Addresses_To_Read, Discovered_Values), Constants, Structures, Addresses_To_Read, Discovered_Values).


