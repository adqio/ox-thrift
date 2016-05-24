-ifndef(_test_types_included).
-define(_test_types_included, yeah).

-define(TEST_THROWTYPE_NORMALRETURN, 0).
-define(TEST_THROWTYPE_DECLAREDEXCEPTION, 1).
-define(TEST_THROWTYPE_UNDECLAREDEXCEPTION, 2).
-define(TEST_THROWTYPE_ERROR, 3).

%% struct 'AllTypes'

-record('AllTypes', {'bool_field' :: boolean(),
                     'byte_field' :: integer(),
                     'i16_field' :: integer(),
                     'i32_field' :: integer(),
                     'i64_field' :: integer(),
                     'double_field' :: float(),
                     'string_field' :: string() | binary(),
                     'int_list' :: list(),
                     'string_set' :: set(),
                     'string_int_map' :: dict()}).
-type 'AllTypes'() :: #'AllTypes'{}.

%% struct 'Integers'

-record('Integers', {'int_field' :: integer(),
                     'int_list' :: list(),
                     'int_set' :: set()}).
-type 'Integers'() :: #'Integers'{}.

%% struct 'Container'

-record('Container', {'first_field' :: integer(),
                      'second_struct' :: 'Integers'(),
                      'third_field' :: integer()}).
-type 'Container'() :: #'Container'{}.

%% struct 'MissingFields'

-record('MissingFields', {'first' :: integer(),
                          'second_skip' :: integer(),
                          'third' :: float(),
                          'fourth_skip' :: list(),
                          'fifth' :: string() | binary(),
                          'sixth_skip' :: 'AllTypes'(),
                          'seventh' :: boolean(),
                          'eighth_skip' :: dict(),
                          'ninth' :: integer()}).
-type 'MissingFields'() :: #'MissingFields'{}.

%% struct 'SimpleException'

-record('SimpleException', {'message' :: string() | binary(),
                            'line_number' :: integer()}).
-type 'SimpleException'() :: #'SimpleException'{}.

%% struct 'UnusedException'

-record('UnusedException', {'unused' :: boolean()}).
-type 'UnusedException'() :: #'UnusedException'{}.

-endif.
