%%
%% Autogenerated by Thrift Compiler (0.9.3)
%%
%% DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
%%

-module(skip_types).

-include("skip_types.hrl").

-export([struct_info/1, struct_info_ext/1]).

struct_info('AllTypes') ->
  {struct, [{1, bool},
          {2, byte},
          {6, i16},
          {5, i32},
          {4, i64},
          {3, double},
          {7, string},
          {8, {list, i32}},
          {9, {set, string}},
          {10, {map, string, i32}}]}
;

struct_info('Integers') ->
  {struct, [{1, i32},
          {2, {list, i32}},
          {3, {set, i32}}]}
;

struct_info('Container') ->
  {struct, [{1, i32},
          {2, {struct, {'skip_types', 'Integers'}}},
          {3, i32}]}
;

struct_info('MissingFields') ->
  {struct, [{1, i32},
          {5, double},
          {9, string},
          {12, bool},
          {15, byte}]}
;

struct_info('SimpleException') ->
  {struct, [{1, string},
          {2, i32}]}
;

struct_info('UnusedException') ->
  {struct, [{1, bool}]}
;

struct_info(_) -> erlang:error(function_clause).

struct_info_ext('AllTypes') ->
  {struct, [{1, optional, bool, 'bool_field', undefined},
          {2, optional, byte, 'byte_field', undefined},
          {6, optional, i16, 'i16_field', undefined},
          {5, optional, i32, 'i32_field', undefined},
          {4, optional, i64, 'i64_field', undefined},
          {3, optional, double, 'double_field', undefined},
          {7, optional, string, 'string_field', undefined},
          {8, optional, {list, i32}, 'int_list', []},
          {9, optional, {set, string}, 'string_set', sets:new()},
          {10, optional, {map, string, i32}, 'string_int_map', dict:new()}]}
;

struct_info_ext('Integers') ->
  {struct, [{1, undefined, i32, 'int_field', undefined},
          {2, undefined, {list, i32}, 'int_list', []},
          {3, undefined, {set, i32}, 'int_set', sets:new()}]}
;

struct_info_ext('Container') ->
  {struct, [{1, undefined, i32, 'first_field', undefined},
          {2, undefined, {struct, {'skip_types', 'Integers'}}, 'second_struct', #'Integers'{}},
          {3, undefined, i32, 'third_field', undefined}]}
;

struct_info_ext('MissingFields') ->
  {struct, [{1, optional, i32, 'first', undefined},
          {5, optional, double, 'third', undefined},
          {9, optional, string, 'fifth', undefined},
          {12, optional, bool, 'seventh', undefined},
          {15, optional, byte, 'ninth', undefined}]}
;

struct_info_ext('SimpleException') ->
  {struct, [{1, undefined, string, 'message', undefined},
          {2, undefined, i32, 'line_number', undefined}]}
;

struct_info_ext('UnusedException') ->
  {struct, [{1, undefined, bool, 'unused', undefined}]}
;

struct_info_ext(_) -> erlang:error(function_clause).

