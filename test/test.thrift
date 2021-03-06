struct AllTypes {
  1:  optional bool bool_field
  2:  optional byte byte_field
  6:  optional i16 i16_field
  5:  optional i32 i32_field
  4:  optional i64 i64_field
  3:  optional double double_field
  7:  optional string string_field
  8:  optional list<i32> int_list
  9:  optional set<string> string_set
  10: optional map<string,i32> string_int_map
}

struct Integers {
  1:  i32 int_field
  2:  list<i32> int_list
  3:  set<i32>  int_set
}

struct Container {
  1:  i32 first_field
  2:  Integers second_struct
  3:  i32 third_field
}

struct MissingFields {
  1:  optional i32 first
  3:  optional i32 second_skip                  // SKIP
  5:  optional double third
  7:  optional list<i32> fourth_skip            // SKIP
  9:  optional string fifth
  10:  optional AllTypes sixth_skip              // SKIP
  12:  optional bool seventh
  14:  optional map<string,i32> eighth_skip      // SKIP
  15:  optional byte ninth
}

exception SimpleException {
  1:  string message
  2:  i32 line_number
}

exception UnusedException {
  1:  bool unused
}

enum ThrowType {
  NormalReturn = 0
  DeclaredException = 1
  UndeclaredException = 2
  Error = 3
}

enum MapRet {
  ReturnMap = 0
  ReturnProplist = 1
}

service TestService {
  i32 add_one(1: i32 input)

  i32 sum_ints(1: Container ints, 2: i32 second)

  AllTypes echo(1: AllTypes all_types)

  i32 throw_exception(1: byte throw_type)
    throws (1: SimpleException e, 2: UnusedException ue)

  void wait(1: i32 milliseconds)

  oneway void cast(1: string message)

  map<string,i32> swapkv(1: MapRet return_type, 2: map<i32,string> input)

  MissingFields missing(1: MissingFields missing)
}

// Local Variables:
// indent-tabs-mode: nil
// comment-start: "// "
// End:
