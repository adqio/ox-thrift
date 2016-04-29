
-include("ox_thrift_internal.hrl").
-include("ox_thrift.hrl").

typeid_to_atom(?tType_STOP)     -> field_stop;
typeid_to_atom(?tType_VOID)     -> void;
typeid_to_atom(?tType_BOOL)     -> bool;
typeid_to_atom(?tType_BYTE)     -> byte;
typeid_to_atom(?tType_DOUBLE)   -> double;
typeid_to_atom(?tType_I16)      -> i16;
typeid_to_atom(?tType_I32)      -> i32;
typeid_to_atom(?tType_I64)      -> i64;
typeid_to_atom(?tType_STRING)   -> string;
typeid_to_atom(?tType_STRUCT)   -> struct;
typeid_to_atom(?tType_MAP)      -> map;
typeid_to_atom(?tType_SET)      -> set;
typeid_to_atom(?tType_LIST)     -> list.

term_to_typeid(void)            -> ?tType_VOID;
term_to_typeid(bool)            -> ?tType_BOOL;
term_to_typeid(byte)            -> ?tType_BYTE;
term_to_typeid(double)          -> ?tType_DOUBLE;
term_to_typeid(i16)             -> ?tType_I16;
term_to_typeid(i32)             -> ?tType_I32;
term_to_typeid(i64)             -> ?tType_I64;
term_to_typeid(string)          -> ?tType_STRING;
term_to_typeid({struct, _})     -> ?tType_STRUCT;
term_to_typeid({map, _, _})     -> ?tType_MAP;
term_to_typeid({set, _})        -> ?tType_SET;
term_to_typeid({list, _})       -> ?tType_LIST.

-define(SUCCESS_FIELD_ID, 0).

-define(VALIDATE(Expr), (fun () -> Expr end)()).

-define(VALIDATE_TYPE(StructType, SuppliedType),
        case term_to_typeid(StructType) of
          SuppliedType -> ok;
          _ -> error(type_mismatch, [ {provided, SuppliedType}, {expected, StructType} ])
        end).


-type message_type() :: 'call' | 'call_oneway' | 'reply_normal' | 'reply_exception' | 'exception'.

-spec encode_call(ServiceModule::atom(), Function::atom(), SeqId::integer(), Args::term()) ->
                     {CallType::message_type(), Data::iolist()}.
encode_call (ServiceModule, Function, SeqId, Args) ->
  CallType = case ServiceModule:function_info(Function, reply_type) of
               oneway_void -> call_oneway;
               _           -> call
             end,
  Data = encode_message(ServiceModule, Function, call, SeqId, Args),
  {CallType, Data}.


-spec encode_message(ServiceModule::atom(), Function::atom(), MessageType::message_type(), SeqId::integer(), Args::term()) -> iolist().
%% `MessageType' is `call', `call_oneway', `reply_normal', 'reply_exception',
%% or `exception'.  If a normal reply, the `Args' argument is a variable of
%% the expected return type for `Function'.  If an exception reply, the `Args'
%% argument is an record of one of the declared exception types.
%%
%% `Args' is a list of function arguments for a `?tMessageType_CALL', and is
%% the reply for a `?tMessageType_REPLY' or exception record for
%% `?tMessageType_EXCEPTION'.
encode_message (ServiceModule, Function, MessageType, SeqId, Args) ->
  case MessageType of
    call ->
      ThriftMessageType = ?tMessageType_CALL,
      MessageSpec = ServiceModule:function_info(Function, params_type),
      ArgsList = list_to_tuple([ Function | Args ]);
    reply_normal ->
      ThriftMessageType = ?tMessageType_REPLY,
      %% Create a fake zero- or one-element structure for the result.
      ReplyName = atom_to_list(Function) ++ "_result",
      case ServiceModule:function_info(Function, reply_type) of
        oneway_void ->
          error(oneway_void), %% This shouldn't happen....
          MessageSpec = undefined,
          ArgsList = undefined;
        ?tVoidReply_Structure ->
          %% A void return
          MessageSpec = ?tVoidReply_Structure,
          ArgsList = {ReplyName};
        ReplySpec ->
          %% A non-void return.
          MessageSpec = {struct, [ {?SUCCESS_FIELD_ID, ReplySpec} ]},
          ArgsList = {ReplyName, Args}
      end;
    reply_exception ->
      %% An exception is treated as a struct with a field for each possible
      %% exception.  Since any given call returns only one exception, all
      %% except one of the fields is `undefined' and so only the field for
      %% the exception actually being thrown is sent over the wire.
      ExceptionName = element(1, Args),
      MessageSpec0 = {struct, ExceptionsSpec} = ServiceModule:function_info(Function, exceptions),
      {ExceptionList, ExceptionFound} =
        lists:mapfoldl(
          fun ({_, {struct, {_, StructExceptionName}}}, FoundAcc) ->
              case StructExceptionName of
                ExceptionName -> {Args, true};
                _             -> {undefined, FoundAcc}
              end
          end, false, ExceptionsSpec),
      ?LOG("exception ~p\n", [ {ExceptionList, ExceptionFound} ]),
      %% If `Exception' is not one of the declared exceptions, turn it into an
      %% application_exception.
      if ExceptionFound ->
          ThriftMessageType = ?tMessageType_REPLY,
          MessageSpec = MessageSpec0,
          ArgsList = list_to_tuple([ Function | ExceptionList ]);
         true ->
          ThriftMessageType = ?tMessageType_EXCEPTION,
          MessageSpec = ?tApplicationException_Structure,
          Message = ox_thrift_util:format_error_message({error_not_declared_as_thrown, Function, ExceptionName}),
          ArgsList = #application_exception{message = Message, type = ?tApplicationException_UNKNOWN}
      end;
    exception ->
      ThriftMessageType = ?tMessageType_EXCEPTION,
      ?VALIDATE(true = is_record(Args, application_exception)),
      MessageSpec = ?tApplicationException_Structure,
      ArgsList = Args
  end,

  ?VALIDATE(begin
              {struct, StructDef} = MessageSpec,
              StructDefLength = length(StructDef),
              ArgsListLength = size(ArgsList) - 1,
              if StructDefLength =/= ArgsListLength ->
                  %% io:format(standard_error, "arg_length_mismatch\ndef ~p\narg ~p\n", [ StructDef, ArgsList ]),
                  error({arg_length_mismatch, {provided, ArgsListLength}, {expected, StructDefLength}});
                 true -> ok
              end
            end),

  [ write(#protocol_message_begin{name = atom_to_binary(Function, latin1), type = ThriftMessageType, seqid = SeqId})
    %% Thrift supports only lists of uniform types, and so it uses a
    %% function-specific struct for a function's argument list.
  , encode(MessageSpec, ArgsList)
  , write(message_end)
  ].


encode ({struct, StructDef}, Data)
  when is_list(StructDef), is_tuple(Data), length(StructDef) == size(Data) - 1 ->
  %% Encode a record from a struct definition.
  [ write(#protocol_struct_begin{name = element(1, Data)})
  , encode_struct(StructDef, Data, 2)
  , write(struct_end)
  ];

encode ({struct, {Schema, StructName}}, Data)
  when is_atom(Schema), is_atom(StructName), is_tuple(Data), element(1, Data) == StructName ->
  %% Encode a record from a schema module.
  encode(Schema:struct_info(StructName), Data);

encode (S={struct, {_Schema, _StructName}}, Data) ->
  error(struct_unmatched, [ S, Data ]);

encode ({list, Type}, Data)
  when is_list(Data) ->
  %% Encode a list.
  EltTId = term_to_typeid(Type),
  [ write(#protocol_list_begin{
                   etype = EltTId,
                   size = length(Data)})
  , lists:map(fun (Elt) -> encode(Type, Elt) end, Data)
  , write(list_end)
  ];

encode ({map, KeyType, ValType}, Data) ->
  %% Encode a map.
  KeyTId = term_to_typeid(KeyType),
  ValTId = term_to_typeid(ValType),
  [ write(#protocol_map_begin{
                   ktype = KeyTId,
                   vtype = ValTId,
                   size = dict:size(Data)})
  , dict:fold(fun (Key, Val, Acc) ->
                  [ encode(KeyType, Key)
                  , encode(ValType, Val)
                  | Acc
                  ]
              end, [], Data)
  , write(map_end)
  ];

encode ({set, Type}, Data) ->
  %% Encode a set.
  EltType = term_to_typeid(Type),
  [ write(#protocol_set_begin{
                   etype = EltType,
                   size = sets:size(Data)})
  , sets:fold(fun (Elt, Acc) -> [ encode(Type, Elt) | Acc ] end, [], Data)
  , write(set_end)
  ];

encode (Type, Data) when is_atom(Type) ->
  %% Encode the basic types.
  TypeId = term_to_typeid(Type),
  write({TypeId, Data});

encode (Type, Data) ->
  error({invalid_type, {type, Type}, {data, Data}}).


-spec encode_struct(FieldData::list({integer(), atom()}), Record::tuple(), I::integer()) -> IOData::iodata().
encode_struct ([ {FieldId, Type} | FieldRest ], Record, I) ->
  %% We could use tail recursion to make this a little more efficient, because
  %% the field order should matter. @@
  case element(I, Record) of
    undefined ->
      %% null fields are skipped
      encode_struct(FieldRest, Record, I+1);
    Data ->
      FieldTypeId = term_to_typeid(Type),
      [ write(#protocol_field_begin{
                       type = FieldTypeId,
                       id = FieldId})
      , encode(Type, Data)
      , write(field_end)
      | encode_struct(FieldRest, Record, I+1)
      ]
  end;

encode_struct ([], _Record, _I) ->
  write(field_stop).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec decode_message(ServiceModule::atom(), Buffer::binary()) ->
                        {Function::atom(), MessageType::message_type(), Seqid::integer(), Args::term()}.
%% `MessageType' is `?tMessageType_CALL' or `?tMessageType_ONEWAY'.
decode_message (ServiceModule, Buffer0) ->
  {Buffer1, #protocol_message_begin{name=FunctionBin, type=ThriftMessageType, seqid=SeqId}} =
    read(Buffer0, message_begin),
  Function = binary_to_atom(FunctionBin, latin1),
  case ThriftMessageType of
    ?tMessageType_CALL ->
      MessageType = case ServiceModule:function_info(Function, reply_type) of
                      oneway_void -> call_oneway;
                      _           -> call
                    end,
      MessageSpec = ServiceModule:function_info(Function, params_type),
      {Buffer2, ArgsTuple} = decode_record(Buffer1, Function, MessageSpec),
      [ _ | Args ] = tuple_to_list(ArgsTuple);
    ?tMessageType_ONEWAY ->
      MessageType = call_oneway,
      MessageSpec = ServiceModule:function_info(Function, params_type),
      {Buffer2, ArgsTuple} = decode_record(Buffer1, Function, MessageSpec),
      [ _ | Args ] = tuple_to_list(ArgsTuple);
    ?tMessageType_REPLY ->
      MessageSpec = ServiceModule:function_info(Function, reply_type),
      {Buffer2, {_, Args}, MessageType} = decode_reply(Buffer1, ServiceModule, Function, MessageSpec);
    ?tMessageType_EXCEPTION ->
      MessageType = exception,
      MessageSpec = ?tApplicationException_Structure,
      {Buffer2, Args} = decode_record(Buffer1, application_exception, MessageSpec)
  end,
  {<<>>, ok} = read(Buffer2, message_end),
  %% io:format(standard_error, "decode\nspec ~p\nargs ~p\n", [ MessageSpec, Args ]),
  {Function, MessageType, SeqId, Args}.


decode_reply (Buffer0, ServiceModule, Function, ReplySpec) ->
  {struct, ExceptionDef} = ServiceModule:function_info(Function, exceptions),
  MessageSpec = {struct, [ {?SUCCESS_FIELD_ID, ReplySpec} | ExceptionDef ]},
  {Buffer1, ArgsTuple} = decode_record(Buffer0, Function, MessageSpec),
  [ F, Reply | Exceptions ] = tuple_to_list(ArgsTuple),
  %% Check for an exception.
  case first_defined(Exceptions)of
    undefined ->
      case ReplySpec of
        ?tVoidReply_Structure -> {Buffer1, {F, ok}, reply_normal};
        _                     -> {Buffer1, {F, Reply}, reply_normal}
      end;
    Exception                 -> {Buffer1, {F, Exception}, reply_exception}
  end.


-spec decode(BufferIn::binary(), Spec::term()) -> {BufferOut::binary(), Decoded::term()}.
decode (Buffer, {struct, {Schema, StructName}})
  when is_atom(Schema), is_atom(StructName) ->
  %% Decode a record from a schema module.
  decode_record(Buffer, StructName, Schema:struct_info(StructName));

decode (Buffer0, {list, Type}) ->
  {Buffer1, #protocol_list_begin{etype=EType, size=Size}} = read(Buffer0, list_begin),
  ?VALIDATE_TYPE(Type, EType),
  {Buffer2, List} = mapfoldn(fun (BufferL0) -> decode(BufferL0, Type) end, Buffer1, Size),
  {Buffer3, ok} = read(Buffer2, list_end),
  {Buffer3, List};

decode (Buffer0, {map, KeyType, ValType}) ->
  {Buffer1, #protocol_map_begin{ktype=KType, vtype=VType, size=Size}} = read(Buffer0, map_begin),
  ?VALIDATE_TYPE(KeyType, KType),
  ?VALIDATE_TYPE(ValType, VType),
  {Buffer2, List} = mapfoldn(fun (BufferL0) ->
                                 {BufferL1, K} = decode(BufferL0, KeyType),
                                 {BufferL2, V} = decode(BufferL1, ValType),
                                 {BufferL2, {K, V}}
                             end, Buffer1, Size),
  {Buffer3, ok} = read(Buffer2, map_end),
  {Buffer3, dict:from_list(List)};

decode (Buffer0, {set, Type}) ->
  {Buffer1, #protocol_set_begin{etype=EType, size=Size}} = read(Buffer0, set_begin),
  ?VALIDATE_TYPE(Type, EType),
  {Buffer2, List} = mapfoldn(fun (BufferL0) -> decode(BufferL0, Type) end, Buffer1, Size),
  {Buffer3, ok} = read(Buffer2, set_end),
  {Buffer3, sets:from_list(List)};

decode (Buffer0, Type) when is_atom(Type) ->
  %% Decode the basic types.
  TypeId = term_to_typeid(Type),
  read(Buffer0, TypeId).


-spec decode_record(BufferIn::binary(), Name::atom(), tuple()) -> {binary(), tuple()}.
decode_record (Buffer0, Name, {struct, StructDef})
  when is_atom(Name), is_list(StructDef) ->
  %% Decode a record from a struct definition.
  {Buffer1, ok} = read(Buffer0, struct_begin),
  %% If we were going to handle field defaults we could create the initialize
  %% here.  It might be better to wait until after the struct is parsed,
  %% however, to avoid unnecessarily creating initializers for fields that
  %% don't need them. @@
  {Buffer2, Record} = decode_struct(Buffer1, StructDef, [ {1, Name} ]),
  {Buffer3, ok} = read(Buffer2, struct_end),
  {Buffer3, Record}.


-spec decode_struct(BufferIn::binary(), FieldList::list(), Acc::list()) -> {binary(), tuple()}.
decode_struct (Buffer0, FieldList, Acc) ->
  {Buffer1, #protocol_field_begin{type=FieldTId, id=FieldId}} = read(Buffer0, field_begin),
  case FieldTId of
    ?tType_STOP ->
      Record = erlang:make_tuple(length(FieldList)+1, undefined, Acc),
      {Buffer1, Record};
    _ ->
      case keyfind(FieldList, FieldId, 2) of %% inefficient @@
        {FieldTypeAtom, N} ->
          ?VALIDATE_TYPE(FieldTypeAtom, FieldTId),
          {Buffer2, Val} = decode(Buffer1, FieldTypeAtom),
          {Buffer3, ok} = read(Buffer2, field_end),
          decode_struct(Buffer3, FieldList, [ {N, Val} | Acc ]);
        false ->
          %% io:format("field ~p not found in ~p\n", [ FieldId, FieldList ]),
          {Buffer2, _} = skip(Buffer1, typeid_to_atom(FieldTId)),
          {Buffer3, ok} = read(Buffer2, field_end),
          decode_struct(Buffer3, FieldList, Acc)
      end
  end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec skip(Buffer0::binary(), Type::atom()) -> {Buffer1::binary(), Dummy::term()}.
skip (Buffer0, struct) ->
  {Buffer1, _} = read(Buffer0, struct_begin),
  Buffer2 = skip_struct(Buffer1),
  read(Buffer2, struct_end);

skip (Buffer0, list) ->
  {Buffer1, #protocol_list_begin{etype=EType, size=Size}} = read(Buffer0, list_begin),
  Buffer2 = foldn(fun (BufferL0) ->
                      {BufferL1, _} = decode(BufferL0, typeid_to_atom(EType)),
                      BufferL1
                  end, Buffer1, Size),
  read(Buffer2, list_end);

skip (Buffer0, map) ->
  {Buffer1, #protocol_map_begin{ktype=KType, vtype=VType, size=Size}} = read(Buffer0, map_begin),
  Buffer2 = foldn(fun (BufferL0) ->
                      {BufferL1, _} = decode(BufferL0, typeid_to_atom(KType)),
                      {BufferL2, _} = decode(BufferL1, typeid_to_atom(VType)),
                      BufferL2
                  end, Buffer1, Size),
  read(Buffer2, map_end);

skip (Buffer0, set) ->
  {Buffer1, #protocol_set_begin{etype=EType, size=Size}} = read(Buffer0, set_begin),
  Buffer2 = foldn(fun (BufferL0) ->
                      {BufferL1, _} = decode(BufferL0, typeid_to_atom(EType)),
                      BufferL1
                  end, Buffer1, Size),
  read(Buffer2, set_end);

skip (Buffer0, Type) when is_atom(Type) ->
  %% Skip the basic types.
  read(Buffer0, Type).


-spec skip_struct (Buffer0::binary()) -> Buffer1::binary().
skip_struct (Buffer0) ->
  {Buffer1, #protocol_field_begin{type=Type}} = read(Buffer0, field_begin),
  case Type of
    ?tType_STOP ->
      Buffer1;
    _ ->
      {Buffer2, _} = skip(Buffer1, typeid_to_atom(Type)),
      {Buffer3, ok} = read(Buffer2, field_end),
      skip_struct(Buffer3)
  end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mapfoldn (F, Acc0, N) when N > 0 ->
  {Acc1, First} = F(Acc0),
  {Acc2, Rest} = mapfoldn(F, Acc1, N-1),
  {Acc2, [ First | Rest ]};
mapfoldn (F, Acc, 0) when is_function(F, 1) ->
  {Acc, []}.


foldn (F, Acc, N) when N > 0 ->
  foldn(F, F(Acc), N-1);
foldn (F, Acc, 0) when is_function(F, 1) ->
  Acc.

%% Similar to `lists:keyfind', but also returns index of the found element.
keyfind ([ {FieldId, FieldTypeAtom} | Rest ], SearchFieldId, I) ->
  if FieldId =:= SearchFieldId -> {FieldTypeAtom, I};
     true                      -> keyfind(Rest, SearchFieldId, I+1)
  end;
keyfind ([], _, _) -> false.

%% Returns the first element of a list that is not `undefined', or `undefined'
%% if all of the elements are `undefined'.
first_defined ([ undefined | Rest ]) ->
  first_defined(Rest);
first_defined ([ First | _ ]) -> First;
first_defined ([]) -> undefined.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-ifdef(EUNIT).

mapfoldn_test () ->
  ?assertEqual({"abcdef", ""}, mapfoldn(fun ([ F | R ]) -> {R, F + $A - $a} end, "abcdef", 0)),
  ?assertEqual({"bcdef", "A"}, mapfoldn(fun ([ F | R ]) -> {R, F + $A - $a} end, "abcdef", 1)),
  ?assertEqual({"def", "ABC"}, mapfoldn(fun ([ F | R ]) -> {R, F + $A - $a} end, "abcdef", 3)),
  ?assertEqual({"", "ABCDEF"}, mapfoldn(fun ([ F | R ]) -> {R, F + $A - $a} end, "abcdef", 6)),
  ?assertError(function_clause, mapfoldn(fun ([ F | R ]) -> {R, F + $A - $a} end, "abcdef", 7)).

foldn_test () ->
  ?assertEqual(1, foldn(fun (E) -> E * 2 end, 1, 0)),
  ?assertEqual(2, foldn(fun (E) -> E * 2 end, 1, 1)),
  ?assertEqual(8, foldn(fun (E) -> E * 2 end, 1, 3)).

keyfind_test () ->
  List = [ {a, apple}, {b, banana}, {c, carrot} ],
  ?assertEqual({apple, 1}, keyfind(List, a, 1)),
  ?assertEqual({carrot, 3}, keyfind(List, c, 1)),
  ?assertEqual(false, keyfind(List, d, 1)).

first_defined_test () ->
  ?assertEqual(undefined, first_defined([])),
  ?assertEqual(1, first_defined([ 1, undefined, 3 ])),
  ?assertEqual(2, first_defined([ undefined, 2, 3 ])).

-endif. %% EUNIT
